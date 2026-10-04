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

$script:DraculaPalette = @('FF5555', 'FFB86C', 'F1FA8C', '50FA7B', '8BE9FD', 'BD93F9', 'FF79C6')

function Get-ContrastWithWhite {
    # WCAG contrast ratio of a color against #FFFFFF.
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#')
    $channels = foreach ($offset in 0, 2, 4) {
        $channel = [Convert]::ToInt32($value.Substring($offset, 2), 16) / 255.0
        if ($channel -le 0.04045) { $channel / 12.92 } else { [Math]::Pow(($channel + 0.055) / 1.055, 2.4) }
    }
    $luminance = 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
    1.05 / ($luminance + 0.05)
}

function ConvertTo-Hsl {
    # Hue (0-360), saturation (0-1) and lightness (0-1) of a color.
    [OutputType([double[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#')
    $red = [Convert]::ToInt32($value.Substring(0, 2), 16) / 255.0
    $green = [Convert]::ToInt32($value.Substring(2, 2), 16) / 255.0
    $blue = [Convert]::ToInt32($value.Substring(4, 2), 16) / 255.0
    $max = [Math]::Max($red, [Math]::Max($green, $blue))
    $min = [Math]::Min($red, [Math]::Min($green, $blue))
    $lightness = ($max + $min) / 2
    if ($max -eq $min) { return [double[]]@(0.0, 0.0, $lightness) }
    $delta = $max - $min
    $saturation = if ($lightness -gt 0.5) { $delta / (2 - $max - $min) } else { $delta / ($max + $min) }
    $hue = if ($max -eq $red) { (($green - $blue) / $delta) % 6 } elseif ($max -eq $green) { ($blue - $red) / $delta + 2 } else { ($red - $green) / $delta + 4 }
    $hue *= 60
    if ($hue -lt 0) { $hue += 360 }
    [double[]]@($hue, $saturation, $lightness)
}

function ConvertFrom-Hsl {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Hue,

        [Parameter(Mandatory)]
        [double]$Saturation,

        [Parameter(Mandatory)]
        [double]$Lightness
    )

    $chroma = (1 - [Math]::Abs(2 * $Lightness - 1)) * $Saturation
    $second = $chroma * (1 - [Math]::Abs((($Hue / 60) % 2) - 1))
    $match = $Lightness - $chroma / 2
    $rgb = switch ([Math]::Floor($Hue / 60) % 6) {
        0 { $chroma, $second, 0 }
        1 { $second, $chroma, 0 }
        2 { 0, $chroma, $second }
        3 { 0, $second, $chroma }
        4 { $second, 0, $chroma }
        default { $chroma, 0, $second }
    }
    ($rgb | ForEach-Object { '{0:X2}' -f [int][Math]::Round(($_ + $match) * 255) }) -join ''
}

function ConvertTo-LightColor {
    # The same color for the light theme, darkened (same hue and saturation) until it has 3:1 contrast on white.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#').ToUpperInvariant()
    if ((Get-ContrastWithWhite -Hex $value) -ge 3) { return $value }
    $hue, $saturation, $lightness = ConvertTo-Hsl -Hex $value
    while ($lightness -gt 0) {
        $lightness = [Math]::Max(0.0, $lightness - 0.01)
        $candidate = ConvertFrom-Hsl -Hue $hue -Saturation $saturation -Lightness $lightness
        if ((Get-ContrastWithWhite -Hex $candidate) -ge 3) { return $candidate }
    }
    '000000'
}

function ConvertTo-DraculaColor {
    # The closest Dracula palette color by hue; greys go to the Dracula foreground or comment color.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $hue, $saturation, $lightness = ConvertTo-Hsl -Hex $Hex
    if ($saturation -lt 0.15) { if ($lightness -ge 0.5) { return 'F8F8F2' } else { return '6272A4' } }
    $best = $null
    $bestDistance = 361.0
    foreach ($candidate in $script:DraculaPalette) {
        $distance = [Math]::Abs((ConvertTo-Hsl -Hex $candidate)[0] - $hue)
        $distance = [Math]::Min($distance, 360 - $distance)
        if ($distance -lt $bestDistance) { $best = $candidate; $bestDistance = $distance }
    }
    $best
}

Export-ModuleMember -Function Confirm-DeviconsData, Read-DeviconsFile, Get-NerdGlyphIndex, Select-GlyphName, Get-ContrastWithWhite, ConvertTo-Hsl, ConvertTo-LightColor, ConvertTo-DraculaColor
