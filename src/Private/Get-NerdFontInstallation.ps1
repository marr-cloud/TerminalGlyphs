function Get-NerdFontInstallation {
    <#
    .SYNOPSIS
        Groups the Nerd Font files in one or more folders by release package and reports which ones are outdated.
    .DESCRIPTION
        A family spread over several folders is reported once, with all its files. Missing folders are skipped.
        The package of a file is found from the part of its name before "NerdFont", using the longest matching
        prefix in -PackageMap (JetBrainsMonoNL and JetBrainsMono both belong to JetBrainsMono). Files without a
        readable Nerd Fonts version count as outdated. Nerd Fonts 2.x files (named like "Hack Regular Nerd Font
        Complete.ttf") are reported together as one outdated 'Nerd Fonts 2.x' object with IsLegacy set.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$FontDirectory,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PackageMap,

        [Parameter(Mandatory)]
        [version]$MinimumVersion
    )

    $existing = @($FontDirectory | Where-Object { $_ -and [System.IO.Directory]::Exists($_) })
    if ($existing.Count -eq 0) { return }
    $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase
    $prefixes = @($PackageMap.Keys | Sort-Object -Property Length -Descending)
    $families = [ordered]@{}
    $fonts = @(Get-ChildItem -LiteralPath $existing -Recurse -File -ErrorAction Ignore |
        Where-Object { $_.Extension -in '.ttf', '.otf' } |
        Sort-Object -Property FullName)
    $files = $fonts | Where-Object { $_.Name.Contains('NerdFont', $ignoreCase) }
    # Nerd Fonts 2.x names files like "Hack Regular Nerd Font Complete.ttf".
    $legacyFiles = @($fonts | Where-Object { $_.Name.Contains(' Nerd Font ', $ignoreCase) -and -not $_.Name.Contains('NerdFont', $ignoreCase) })
    foreach ($file in $files) {
        $stem = $file.Name.Substring(0, $file.Name.IndexOf('NerdFont', $ignoreCase))
        $prefix = $prefixes | Where-Object { $stem.StartsWith($_, $ignoreCase) } | Select-Object -First 1
        $package = if ($prefix) { $PackageMap[$prefix] } else { $null }
        $key = if ($package) { $package } else { "?$stem" }
        if (-not $families.Contains($key)) {
            $families[$key] = [pscustomobject]@{
                PSTypeName = 'TerminalGlyphs.NerdFontFamily'
                Name       = if ($package) { $package } else { $stem }
                Package    = $package
                Files      = [System.Collections.Generic.List[string]]::new()
                Version    = $null
                IsOutdated = $false
                IsLegacy   = $false
            }
        }
        $entry = $families[$key]
        $entry.Files.Add($file.FullName)
        $info = Read-FontInfo -Path $file.FullName
        if ($null -eq $info -or $null -eq $info.Version) {
            $entry.IsOutdated = $true
            continue
        }
        if ($null -eq $entry.Version -or $info.Version -lt $entry.Version) { $entry.Version = $info.Version }
        if ($info.Version -lt $MinimumVersion) { $entry.IsOutdated = $true }
    }
    $families.Values
    if ($legacyFiles.Count -gt 0) {
        $legacyVersion = $null
        foreach ($file in $legacyFiles) {
            $info = Read-FontInfo -Path $file.FullName
            if ($null -ne $info -and $null -ne $info.Version -and ($null -eq $legacyVersion -or $info.Version -lt $legacyVersion)) { $legacyVersion = $info.Version }
        }
        [pscustomobject]@{
            PSTypeName = 'TerminalGlyphs.NerdFontFamily'
            Name       = 'Nerd Fonts 2.x'
            Package    = $null
            Files      = [System.Collections.Generic.List[string]]@($legacyFiles.FullName)
            Version    = $legacyVersion
            IsOutdated = $true
            IsLegacy   = $true
        }
    }
}
