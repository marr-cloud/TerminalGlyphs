<#
.SYNOPSIS
    Builds TerminalGlyphs into out/TerminalGlyphs/<version>/ and optionally runs the tests.
.EXAMPLE
    ./build.ps1
    Validates the themes and builds the module.
.EXAMPLE
    ./build.ps1 -Task Test
    Builds, then runs Pester (the Performance tag is excluded by default).
.EXAMPLE
    ./build.ps1 -Task Test -Tag Performance -ExcludeTag @()
    Builds, then runs only the performance tests.
#>
[CmdletBinding()]
param(
    [ValidateSet('Build', 'Test')]
    [string]$Task = 'Build',

    [string]$ThemesPath = ([System.IO.Path]::Combine($PSScriptRoot, 'themes')),

    [string]$OutputPath = ([System.IO.Path]::Combine($PSScriptRoot, 'out')),

    [string]$VendorPath = ([System.IO.Path]::Combine($PSScriptRoot, 'vendor', 'nerd-fonts')),

    [string[]]$Tag,

    [string[]]$ExcludeTag = @('Performance')
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
foreach ($helper in 'Read-JsoncFile', 'Get-GlyphThemeEntry', 'Test-GlyphThemeEntry', 'ConvertTo-AnsiSequence') {
    . ([System.IO.Path]::Combine($root, 'src', 'Private', "$helper.ps1"))
}

function Confirm-NerdFontData {
    param([string]$VendorPath)
    # Every vendored Nerd Fonts file the build reads must match manifest.json, so a partial update fails here instead
    # of at download time.
    $manifestPath = [System.IO.Path]::Combine($VendorPath, 'manifest.json')
    if (-not [System.IO.File]::Exists($manifestPath)) { throw "$manifestPath is missing; it records the version and SHA-256 of the vendored Nerd Fonts files." }
    $manifest = Read-JsoncFile -Path $manifestPath
    $files = $manifest['files']
    foreach ($name in 'glyphnames.json', 'fonts.json', 'SHA-256.txt') {
        if ($null -eq $files -or -not $files.Contains($name)) { throw "manifest.json does not list $name; add its SHA-256 to $manifestPath." }
        $path = [System.IO.Path]::Combine($VendorPath, $name)
        if (-not [System.IO.File]::Exists($path)) { throw "$name is listed in manifest.json but missing: $path" }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actual -ne $files[$name]) {
            throw "$path does not match manifest.json (expected SHA-256 $($files[$name]), got $actual). Update the file and manifest.json together."
        }
    }
    [string]$manifest['version']
}

function Get-NerdGlyphSet {
    param([string]$VendorPath)
    $raw = Read-JsoncFile -Path ([System.IO.Path]::Combine($VendorPath, 'glyphnames.json'))
    $map = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($name in $raw.Keys) {
        if ($name -ceq 'METADATA') { continue }
        $map["nf-$name"] = [char]::ConvertFromUtf32([Convert]::ToInt32($raw[$name]['code'], 16))
    }
    [pscustomobject]@{ Version = [string]$raw['METADATA']['version']; Glyphs = $map }
}

function Read-ThemeDirectory {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Glyphs', Justification = 'Used inside the GlyphExists scriptblock; the analyzer does not see it.')]
    param(
        [string]$Path,
        [ValidateSet('Icon', 'Color')][string]$ThemeType,
        [System.Collections.Generic.SortedDictionary[string, string]]$Glyphs,
        [System.Collections.Generic.List[string]]$Errors
    )
    $themes = [ordered]@{}
    foreach ($file in (Get-ChildItem -LiteralPath $Path -Filter '*.jsonc' | Sort-Object Name)) {
        try {
            $theme = Read-JsoncFile -Path $file.FullName
        } catch {
            $Errors.Add("$($file.Name): $($_.Exception.Message)")
            continue
        }
        if ($theme['name'] -cne $file.BaseName) { $Errors.Add("$($file.Name): 'name' must be '$($file.BaseName)'") }
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in (Get-GlyphThemeEntry -Theme $theme)) {
            $problem = Test-GlyphThemeEntry -Entry $entry -ThemeType $ThemeType -GlyphExists { param($name) $Glyphs.ContainsKey([string]$name) }
            if ($problem) { $Errors.Add("$($file.Name): $problem"); continue }
            if ($null -ne $entry.Key -and -not $seen.Add("$($entry.Kind).$($entry.Section).$($entry.Key)")) {
                $Errors.Add("$($file.Name): duplicate key '$($entry.Key)' in $($entry.Kind).$($entry.Section) (keys are case-insensitive)")
            }
            if ($ThemeType -eq 'Color') {
                $normalized = $entry.Value.TrimStart('#').ToUpperInvariant()
                if ($entry.Section -ceq 'default') { $theme[$entry.Kind]['default'] = $normalized }
                else { $theme[$entry.Kind][$entry.Section][$entry.Key] = $normalized }
            }
        }
        $themes[$file.BaseName] = $theme
    }
    $themes
}

function Invoke-ModuleBuild {
    param([string]$ThemesPath, [string]$OutputPath, [string]$VendorPath)
    $manifest = Import-PowerShellDataFile -LiteralPath ([System.IO.Path]::Combine($root, 'src', 'TerminalGlyphs.psd1'))
    $vendorVersion = Confirm-NerdFontData -VendorPath $VendorPath
    $nerd = Get-NerdGlyphSet -VendorPath $VendorPath
    if ($vendorVersion -ne $nerd.Version) {
        throw "vendor/nerd-fonts/manifest.json is for Nerd Fonts $vendorVersion but glyphnames.json is $($nerd.Version)."
    }
    $errors = [System.Collections.Generic.List[string]]::new()
    $iconThemes = Read-ThemeDirectory -Path ([System.IO.Path]::Combine($ThemesPath, 'icons')) -ThemeType Icon -Glyphs $nerd.Glyphs -Errors $errors
    $colorThemes = Read-ThemeDirectory -Path ([System.IO.Path]::Combine($ThemesPath, 'colors')) -ThemeType Color -Glyphs $nerd.Glyphs -Errors $errors
    if (-not $iconThemes.Contains('default')) { $errors.Add('missing icons/default.jsonc') }
    if (-not $colorThemes.Contains('default')) { $errors.Add('missing colors/default.jsonc') }
    if ($errors.Count -gt 0) { throw "Theme validation failed:`n  - $($errors -join "`n  - ")" }

    $used = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    $used['nf-md-arrow_right_thick'] = $nerd.Glyphs['nf-md-arrow_right_thick']
    foreach ($theme in $iconThemes.Values) {
        foreach ($entry in (Get-GlyphThemeEntry -Theme $theme)) { $used[$entry.Value] = $nerd.Glyphs[$entry.Value] }
    }

    # Remove every earlier version, so out/ never holds stale module folders. Only folders named like a version are
    # removed, and a source checkout is refused, so a mistaken -OutputPath cannot delete anything else.
    $moduleRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($OutputPath, 'TerminalGlyphs'))
    foreach ($marker in 'build.ps1', '.git') {
        if (Test-Path -LiteralPath ([System.IO.Path]::Combine($moduleRoot, $marker))) {
            throw "Refusing to build into $moduleRoot because it is a TerminalGlyphs source folder. Use an -OutputPath outside the repository (default: out)."
        }
    }
    $moduleDir = [System.IO.Path]::Combine($moduleRoot, $manifest.ModuleVersion)
    if ([System.IO.Directory]::Exists($moduleRoot)) {
        foreach ($folder in [System.IO.Directory]::GetDirectories($moduleRoot)) {
            $parsed = $null
            if ([version]::TryParse([System.IO.Path]::GetFileName($folder), [ref]$parsed)) { Remove-Item -LiteralPath $folder -Recurse -Force }
        }
    }
    [System.IO.Directory]::CreateDirectory($moduleDir) | Out-Null
    $utf8 = [System.Text.UTF8Encoding]::new($false)

    # The ANSI sequence of every theme color, so the first listing does not convert them one by one.
    $ansi = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($theme in $colorThemes.Values) {
        foreach ($entry in (Get-GlyphThemeEntry -Theme $theme)) {
            $ansi[$entry.Value.TrimStart('#').ToUpperInvariant()] = ConvertTo-AnsiSequence -Hex $entry.Value
        }
    }

    $data = [ordered]@{ nerdFontsVersion = $nerd.Version; glyphs = $used; ansi = $ansi; iconThemes = $iconThemes; colorThemes = $colorThemes }
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'TerminalGlyphs.data.json'), ($data | ConvertTo-Json -Depth 10 -Compress), $utf8)
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'glyphs.json'), ($nerd.Glyphs | ConvertTo-Json -Compress), $utf8)

    $fontIndex = Read-JsoncFile -Path ([System.IO.Path]::Combine($VendorPath, 'fonts.json'))
    $packages = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($font in $fontIndex['fonts']) { $packages[$font['patchedName'].Replace(' ', '')] = $font['folderName'] }
    # Checksums ship with the module, so a download is never checked against a file from the same server.
    $archives = [System.Collections.Generic.SortedDictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($line in [System.IO.File]::ReadAllLines([System.IO.Path]::Combine($VendorPath, 'SHA-256.txt'))) {
        if ($line -match '^([0-9a-f]{64})\s+(\S+)\.tar\.xz$') { $archives[$Matches[2]] = $Matches[1] }
    }
    foreach ($package in $packages.Values) {
        if (-not $archives.ContainsKey($package)) { throw "vendor/nerd-fonts/SHA-256.txt has no checksum for $package.tar.xz" }
    }
    $nerdFonts = [ordered]@{ version = $nerd.Version; packages = $packages; archives = $archives }
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'nerdfonts.json'), ($nerdFonts | ConvertTo-Json -Compress), $utf8)

    $psm1 = [System.Text.StringBuilder]::new()
    $sources = Get-ChildItem -LiteralPath ([System.IO.Path]::Combine($root, 'src', 'Private')), ([System.IO.Path]::Combine($root, 'src', 'Public')) -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($file in $sources) { [void]$psm1.AppendLine([System.IO.File]::ReadAllText($file.FullName)) }
    [void]$psm1.Append([System.IO.File]::ReadAllText([System.IO.Path]::Combine($root, 'src', 'TerminalGlyphs.psm1')))
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($moduleDir, 'TerminalGlyphs.psm1'), $psm1.ToString(), $utf8)

    foreach ($file in 'TerminalGlyphs.psd1', 'TerminalGlyphs.format.ps1xml') {
        Copy-Item -LiteralPath ([System.IO.Path]::Combine($root, 'src', $file)) -Destination $moduleDir
    }
    foreach ($file in 'LICENSE', 'THIRD_PARTY_NOTICES.md') {
        $path = [System.IO.Path]::Combine($root, $file)
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $moduleDir }
    }
    Write-Host "Built TerminalGlyphs $($manifest.ModuleVersion) -> $moduleDir"
}

Invoke-ModuleBuild -ThemesPath $ThemesPath -OutputPath $OutputPath -VendorPath $VendorPath

if ($Task -eq 'Test') {
    Import-Module Pester -MinimumVersion 5.9.0 -MaximumVersion 5.99.99 -ErrorAction Stop
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = [System.IO.Path]::Combine($root, 'tests')
    $configuration.Run.Throw = $true
    $configuration.Output.Verbosity = 'Detailed'
    if ($Tag) { $configuration.Filter.Tag = $Tag }
    if ($ExcludeTag) { $configuration.Filter.ExcludeTag = $ExcludeTag }
    Invoke-Pester -Configuration $configuration
}
