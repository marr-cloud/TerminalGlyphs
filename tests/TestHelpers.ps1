# Shared helpers for the TerminalGlyphs tests. Dot-source this file from BeforeAll.
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

function Get-BuiltManifestPath {
    $version = (Import-PowerShellDataFile -Path (Join-Path $script:RepoRoot 'src' 'TerminalGlyphs.psd1')).ModuleVersion
    $path = Join-Path $script:RepoRoot 'out' 'TerminalGlyphs' $version 'TerminalGlyphs.psd1'
    if (-not (Test-Path -LiteralPath $path)) { throw "Module not built: $path. Run ./build.ps1 first." }
    $path
}

function Start-IsolatedPwsh {
    param(
        [Parameter(Mandatory)][string]$Command,
        [hashtable]$Environment = @{}
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new([Environment]::ProcessPath)
    $script = "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`n$Command"
    foreach ($argument in @('-NoProfile', '-NoLogo', '-NonInteractive', '-Command', $script)) {
        $psi.ArgumentList.Add($argument)
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    foreach ($name in $Environment.Keys) {
        if ($null -eq $Environment[$name]) { [void]$psi.Environment.Remove($name) }
        else { $psi.Environment[$name] = [string]$Environment[$name] }
    }
    $process = [System.Diagnostics.Process]::Start($psi)
    [pscustomobject]@{
        Process = $process
        Stdout  = $process.StandardOutput.ReadToEndAsync()
        Stderr  = $process.StandardError.ReadToEndAsync()
    }
}

function Wait-IsolatedPwsh {
    param(
        [Parameter(Mandatory, ValueFromPipeline)][psobject]$Handle,
        [int]$TimeoutSeconds = 120
    )
    process {
        if (-not $Handle.Process.WaitForExit($TimeoutSeconds * 1000)) {
            $Handle.Process.Kill($true)
            throw "Child pwsh did not exit within $TimeoutSeconds seconds."
        }
        $Handle.Process.WaitForExit()
        $stdout = $Handle.Stdout.GetAwaiter().GetResult()
        $stderr = $Handle.Stderr.GetAwaiter().GetResult()
        [pscustomobject]@{ ExitCode = $Handle.Process.ExitCode; Output = $stdout; Error = $stderr; All = $stdout + $stderr }
    }
}

function Invoke-IsolatedPwsh {
    param(
        [Parameter(Mandatory)][string]$Command,
        [hashtable]$Environment = @{},
        [int]$TimeoutSeconds = 120
    )
    Start-IsolatedPwsh -Command $Command -Environment $Environment | Wait-IsolatedPwsh -TimeoutSeconds $TimeoutSeconds
}

function Get-TreeSnapshot {
    param([Parameter(Mandatory)][string[]]$Path)
    foreach ($root in $Path) {
        if (-not (Test-Path -LiteralPath $root)) { "$root|<missing>"; continue }
        Get-ChildItem -LiteralPath $root -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
            '{0}|{1}|{2}|{3}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
}

function New-FileFixture {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string[]]$File = @(),
        [string[]]$Directory = @()
    )
    [System.IO.Directory]::CreateDirectory($Root) | Out-Null
    foreach ($name in $Directory) { [System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($Root, $name)) | Out-Null }
    foreach ($name in $File) { [System.IO.File]::WriteAllText([System.IO.Path]::Combine($Root, $name), '') }
    $Root
}

function Get-GlyphChar {
    param([Parameter(Mandatory)][string]$Name)
    if (-not $script:NerdGlyphs) {
        $script:NerdGlyphs = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'vendor' 'nerd-fonts' 'glyphnames.json') -Raw | ConvertFrom-Json -AsHashtable
    }
    $entry = $script:NerdGlyphs[$Name.Substring(3)]
    if (-not $entry) { throw "Unknown glyph $Name" }
    [char]::ConvertFromUtf32([Convert]::ToInt32($entry['code'], 16))
}

function New-TestFont {
    # A minimal sfnt with only a 'name' table: enough for Read-FontInfo, not a usable font.
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$FullName = 'Test NFM Regular',
        [string]$Family = 'Test NFM',
        [string]$TypographicFamily = 'Test Nerd Font Mono',
        [string]$Version = 'Version 1.000;Nerd Fonts 3.5.1'
    )
    $records = [System.Collections.Generic.List[object]]::new()
    $records.Add(@(1, 0x409, $Family))
    $records.Add(@(4, 0x409, $FullName))
    $records.Add(@(5, 0x409, $Version))
    if ($TypographicFamily) {
        # A British English record first: Read-FontInfo must prefer US English, as real Nerd Fonts need.
        $records.Add(@(16, 0x809, 'Wrong Family'))
        $records.Add(@(16, 0x409, $TypographicFamily))
    }
    $put = {
        param($List, [long]$Value, [int]$Size)
        for ($shift = 8 * ($Size - 1); $shift -ge 0; $shift -= 8) { $List.Add([byte](($Value -shr $shift) -band 0xFF)) }
    }
    $strings = [System.Collections.Generic.List[byte]]::new()
    $table = [System.Collections.Generic.List[byte]]::new()
    & $put $table 0 2
    & $put $table $records.Count 2
    & $put $table (6 + 12 * $records.Count) 2
    foreach ($record in $records) {
        $text = [System.Text.Encoding]::BigEndianUnicode.GetBytes([string]$record[2])
        & $put $table 3 2
        & $put $table 1 2
        & $put $table $record[1] 2
        & $put $table $record[0] 2
        & $put $table $text.Length 2
        & $put $table $strings.Count 2
        $strings.AddRange($text)
    }
    $table.AddRange($strings)
    $font = [System.Collections.Generic.List[byte]]::new()
    & $put $font 0x00010000 4
    & $put $font 1 2
    & $put $font 16 2
    & $put $font 0 2
    & $put $font 0 2
    $font.AddRange([byte[]][char[]]'name')
    & $put $font 0 4
    & $put $font 28 4
    & $put $font $table.Count 4
    $font.AddRange($table)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($Path)) | Out-Null
    [System.IO.File]::WriteAllBytes($Path, $font.ToArray())
    $Path
}
