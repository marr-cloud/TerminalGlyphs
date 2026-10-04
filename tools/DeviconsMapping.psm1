# Functions for tools/Import-DeviconsMapping.ps1: import file icons and colors from the vendored nvim-web-devicons data.
. ([System.IO.Path]::Combine($PSScriptRoot, '..', 'src', 'Private', 'Read-JsoncFile.ps1'))

$script:FamilyOrder = @('dev', 'seti', 'custom', 'md', 'fa', 'oct', 'cod')

function Confirm-DeviconsData {
    # Returns the reference commit after checking every data file against manifest.json.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VendorPath
    )

    $manifestPath = [System.IO.Path]::Combine($VendorPath, 'manifest.json')
    if (-not [System.IO.File]::Exists($manifestPath)) { throw "$manifestPath is missing." }
    $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -AsHashtable
    foreach ($name in 'icons_by_filename.lua', 'icons_by_file_extension.lua') {
        if ($null -eq $manifest['files'] -or -not $manifest['files'].Contains($name)) { throw "manifest.json does not list $name." }
        $path = [System.IO.Path]::Combine($VendorPath, $name)
        if (-not [System.IO.File]::Exists($path)) { throw "$name is listed in manifest.json but missing: $path" }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actual -ne $manifest['files'][$name]) {
            throw "$path does not match manifest.json (expected SHA-256 $($manifest['files'][$name]), got $actual)."
        }
    }
    [string]$manifest['commit']
}

function Read-DeviconsFile {
    # One object per entry of an nvim-web-devicons table: Key, Icon, Color (RRGGBB) and Group (the entry's name).
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Extension
    )

    $text = [System.IO.File]::ReadAllText($Path)
    $pattern = '\["(?<key>[^"]+)"\]\s*=\s*\{\s*icon\s*=\s*"(?<icon>[^"]*)",\s*color\s*=\s*"#(?<color>[0-9A-Fa-f]{6})",\s*cterm_color\s*=\s*"\d+",\s*name\s*=\s*"(?<name>[^"]+)"\s*,?\s*\}'
    foreach ($match in [regex]::Matches($text, $pattern)) {
        $key = $match.Groups['key'].Value
        if ($Extension) { $key = ".$key" }
        [pscustomobject]@{
            Key   = $key
            Icon  = $match.Groups['icon'].Value
            Color = $match.Groups['color'].Value.ToUpperInvariant()
            Group = $match.Groups['name'].Value
        }
    }
}

function Get-NerdGlyphIndex {
    # Code point -> Nerd Fonts names (nf-...) from glyphnames.json.
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GlyphNamesPath
    )

    $raw = Read-JsoncFile -Path $GlyphNamesPath
    $index = @{}
    foreach ($name in $raw.Keys) {
        if ($name -ceq 'METADATA') { continue }
        $code = [Convert]::ToInt32($raw[$name]['code'], 16)
        if (-not $index.ContainsKey($code)) { $index[$code] = [System.Collections.Generic.List[string]]::new() }
        $index[$code].Add("nf-$name")
    }
    $index
}

function Select-GlyphName {
    # One name for a code point: a name the theme already uses, else by family order, then length, then name.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$CodePoint,

        [Parameter(Mandatory)]
        [hashtable]$GlyphIndex,

        [System.Collections.Generic.HashSet[string]]$UsedName
    )

    if (-not $GlyphIndex.ContainsKey($CodePoint)) { return }
    $names = $GlyphIndex[$CodePoint]
    if ($UsedName) {
        $used = $names | Where-Object { $UsedName.Contains($_) } | Sort-Object | Select-Object -First 1
        if ($used) { return $used }
    }
    $rank = {
        $family = ($_ -split '-')[1]
        $position = [array]::IndexOf($script:FamilyOrder, $family)
        if ($position -lt 0) { 100 } else { $position }
    }
    $names | Sort-Object -Property @(
        @{ Expression = $rank }
        @{ Expression = { ($_ -split '-')[1] } }
        @{ Expression = { $_.Length } }
        @{ Expression = { $_ } }
    ) | Select-Object -First 1
}

Export-ModuleMember -Function Confirm-DeviconsData, Read-DeviconsFile, Get-NerdGlyphIndex, Select-GlyphName
