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
    # The same color for the light theme, darkened (same hue and chroma) until it has 3:1 contrast on white.
    # HSL saturation is not kept: almost white colors have a high saturation and would turn vivid when darkened.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#').ToUpperInvariant()
    if ((Get-ContrastWithWhite -Hex $value) -ge 3) { return $value }
    $hue, $saturation, $lightness = ConvertTo-Hsl -Hex $value
    $chroma = (1 - [Math]::Abs(2 * $lightness - 1)) * $saturation
    while ($lightness -gt 0) {
        $lightness = [Math]::Max(0.0, $lightness - 0.01)
        $room = 1 - [Math]::Abs(2 * $lightness - 1)
        $candidateSaturation = if ($room -gt 0) { [Math]::Min(1.0, $chroma / $room) } else { 0.0 }
        $candidate = ConvertFrom-Hsl -Hue $hue -Saturation $candidateSaturation -Lightness $lightness
        if ((Get-ContrastWithWhite -Hex $candidate) -ge 3) { return $candidate }
    }
    '000000'
}

function ConvertTo-DraculaColor {
    # The closest Dracula palette color by hue; greys go to the Dracula foreground or comment color. Grey means a low
    # HSV saturation: HSL saturation is high for almost white colors with a tint, which would turn vivid.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $hue, $saturation, $lightness = ConvertTo-Hsl -Hex $Hex
    $chroma = (1 - [Math]::Abs(2 * $lightness - 1)) * $saturation
    $brightness = $lightness + $chroma / 2
    $hsvSaturation = if ($brightness -gt 0) { $chroma / $brightness } else { 0.0 }
    if ($hsvSaturation -lt 0.2) { if ($lightness -ge 0.5) { return 'F8F8F2' } else { return '6272A4' } }
    $best = $null
    $bestDistance = 361.0
    foreach ($candidate in $script:DraculaPalette) {
        $distance = [Math]::Abs((ConvertTo-Hsl -Hex $candidate)[0] - $hue)
        $distance = [Math]::Min($distance, 360 - $distance)
        if ($distance -lt $bestDistance) { $best = $candidate; $bestDistance = $distance }
    }
    $best
}

function Find-ThemeKey {
    # The key as written in a theme section that equals -Key without case, or nothing.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary]$Map,

        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($null -eq $Map) { return }
    $Map.Keys | Where-Object { $_ -eq $Key } | Select-Object -First 1
}

function Get-DeviconsComparison {
    # Compares the reference with the themes: new entries, other glyphs, unnamed glyphs and icons without a color.
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VendorPath,

        [Parameter(Mandatory)]
        [string]$GlyphNamesPath,

        [Parameter(Mandatory)]
        [string]$ThemesPath
    )

    $commit = Confirm-DeviconsData -VendorPath $VendorPath
    $index = Get-NerdGlyphIndex -GlyphNamesPath $GlyphNamesPath
    $codeOf = @{}
    foreach ($code in $index.Keys) { foreach ($name in $index[$code]) { $codeOf[$name] = $code } }
    $icons = Read-JsoncFile -Path ([System.IO.Path]::Combine($ThemesPath, 'icons', 'default.jsonc'))
    $colors = [ordered]@{}
    foreach ($theme in 'default', 'light', 'dracula') { $colors[$theme] = Read-JsoncFile -Path ([System.IO.Path]::Combine($ThemesPath, 'colors', "$theme.jsonc")) }

    $used = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($kind in 'files', 'directories') {
        if ($null -eq $icons[$kind]) { continue }
        foreach ($value in $icons[$kind].Values) {
            if ($value -is [System.Collections.IDictionary]) { foreach ($name in $value.Values) { [void]$used.Add([string]$name) } }
            elseif ($value -is [string]) { [void]$used.Add($value) }
        }
    }

    $result = [pscustomobject]@{
        Commit       = $commit
        New          = [System.Collections.Generic.List[object]]::new()
        Different    = [System.Collections.Generic.List[object]]::new()
        Unmapped     = [System.Collections.Generic.List[object]]::new()
        MissingColor = [System.Collections.Generic.List[object]]::new()
        MissingFolderColor = [System.Collections.Generic.List[object]]::new()
    }
    $reference = @{}
    foreach ($source in @(@{ File = 'icons_by_filename.lua'; Section = 'names'; Extension = $false }, @{ File = 'icons_by_file_extension.lua'; Section = 'extensions'; Extension = $true })) {
        $reference[$source.Section] = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $map = $icons['files'][$source.Section]
        $colorMap = $colors['default']['files'][$source.Section]
        foreach ($entry in (Read-DeviconsFile -Path ([System.IO.Path]::Combine($VendorPath, $source.File)) -Extension:$source.Extension)) {
            $reference[$source.Section][$entry.Key] = $entry
            $codePoint = [char]::ConvertToUtf32($entry.Icon, 0)
            $glyph = Select-GlyphName -CodePoint $codePoint -GlyphIndex $index -UsedName $used
            if (-not $glyph) {
                $result.Unmapped.Add([pscustomobject]@{ Section = $source.Section; Key = $entry.Key; Group = $entry.Group; CodePoint = ('U+{0:X4}' -f $codePoint) })
                continue
            }
            $currentKey = Find-ThemeKey -Map $map -Key $entry.Key
            $item = [pscustomobject]@{
                Section      = $source.Section
                Key          = $entry.Key
                Group        = $entry.Group
                Glyph        = $glyph
                Color        = $entry.Color
                CurrentKey   = $currentKey
                CurrentGlyph = if ($currentKey) { $map[$currentKey] } else { $null }
                CurrentColor = $null
            }
            if ($currentKey) {
                $colorKey = Find-ThemeKey -Map $colorMap -Key $currentKey
                if ($colorKey) { $item.CurrentColor = $colorMap[$colorKey] }
            }
            if (-not $currentKey) { $result.New.Add($item) }
            elseif ($codeOf[[string]$item.CurrentGlyph] -ne $codePoint) { $result.Different.Add($item) }
        }
    }

    foreach ($section in 'names', 'extensions') {
        $map = $icons['files'][$section]
        if ($null -eq $map) { continue }
        foreach ($key in $map.Keys) {
            $missing = @(foreach ($theme in $colors.Keys) { if (-not (Find-ThemeKey -Map $colors[$theme]['files'][$section] -Key $key)) { $theme } })
            if ($missing.Count -eq 0) { continue }
            $referenceColor = if ($reference[$section].ContainsKey($key)) { $reference[$section][$key].Color } else { $null }
            $result.MissingColor.Add([pscustomobject]@{ Section = $section; Key = $key; MissingIn = [string[]]$missing; ReferenceColor = $referenceColor })
        }
    }
    # Folders are not in the reference: they are only reported.
    if ($icons['directories'] -and $icons['directories']['names']) {
        foreach ($key in $icons['directories']['names'].Keys) {
            $missing = @(foreach ($theme in $colors.Keys) { if (-not $colors[$theme]['directories'] -or -not (Find-ThemeKey -Map $colors[$theme]['directories']['names'] -Key $key)) { $theme } })
            if ($missing.Count -gt 0) { $result.MissingFolderColor.Add([pscustomobject]@{ Key = $key; MissingIn = [string[]]$missing }) }
        }
    }
    $result
}

function Write-DeviconsReport {
    # Writes the comparison as Markdown, grouping new entries by the reference's name for each entry.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Comparison,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $cell = { param($Value) ([string]$Value).Replace('|', '\|') }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# nvim-web-devicons mappings report')
    $lines.Add('')
    $lines.Add("Reference: https://github.com/nvim-tree/nvim-web-devicons commit $($Comparison.Commit)")
    $lines.Add('')
    $lines.Add('| | Count |')
    $lines.Add('|---|---|')
    $lines.Add("| New file names | $(@($Comparison.New | Where-Object Section -EQ 'names').Count) |")
    $lines.Add("| New extensions | $(@($Comparison.New | Where-Object Section -EQ 'extensions').Count) |")
    $lines.Add("| Existing entries with another glyph | $($Comparison.Different.Count) |")
    $lines.Add("| Glyphs without a Nerd Fonts 3.5.1 name | $($Comparison.Unmapped.Count) |")
    $lines.Add("| Icons without a color in some theme | $($Comparison.MissingColor.Count) |")
    $lines.Add('')
    $lines.Add('## New entries')
    foreach ($group in ($Comparison.New | Group-Object -Property Group | Sort-Object -Property Name)) {
        $lines.Add('')
        $lines.Add("### $($group.Name)")
        $lines.Add('')
        $lines.Add('| Section | Key | Glyph | Color |')
        $lines.Add('|---|---|---|---|')
        foreach ($item in ($group.Group | Sort-Object -Property Section, Key)) {
            $lines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Section, (& $cell $item.Key), $item.Glyph, $item.Color))
        }
    }
    $lines.Add('')
    $lines.Add('## Existing entries with another glyph')
    $lines.Add('')
    $lines.Add('| Section | Key | Current glyph | Reference glyph | Current color | Reference color |')
    $lines.Add('|---|---|---|---|---|---|')
    foreach ($item in ($Comparison.Different | Sort-Object -Property Section, Key)) {
        $lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $item.Section, (& $cell $item.Key), $item.CurrentGlyph, $item.Glyph, $item.CurrentColor, $item.Color))
    }
    $lines.Add('')
    $lines.Add('## Glyphs without a Nerd Fonts 3.5.1 name')
    $lines.Add('')
    $lines.Add('| Section | Key | Group | Code point |')
    $lines.Add('|---|---|---|---|')
    foreach ($item in $Comparison.Unmapped) { $lines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Section, (& $cell $item.Key), $item.Group, $item.CodePoint)) }
    $lines.Add('')
    $lines.Add('## Icons without a color')
    $lines.Add('')
    $lines.Add('| Section | Key | Missing in | Reference color |')
    $lines.Add('|---|---|---|---|')
    foreach ($item in ($Comparison.MissingColor | Sort-Object -Property Section, Key)) {
        $lines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Section, (& $cell $item.Key), ($item.MissingIn -join ', '), $item.ReferenceColor))
    }
    $lines.Add('')
    $lines.Add('## Folders without a color')
    $lines.Add('')
    $lines.Add('For information only: the reference has no folder icons.')
    $lines.Add('')
    $lines.Add('| Folder | Missing in |')
    $lines.Add('|---|---|')
    foreach ($item in ($Comparison.MissingFolderColor | Sort-Object -Property Key)) { $lines.Add(('| {0} | {1} |' -f (& $cell $item.Key), ($item.MissingIn -join ', '))) }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($Path))) | Out-Null
    [System.IO.File]::WriteAllText($Path, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}

$script:CreditLine = '// Some entries from nvim-web-devicons (https://github.com/nvim-tree/nvim-web-devicons). MIT License. See THIRD_PARTY_NOTICES.md.'

function Add-ThemeCreditLine {
    # Adds the nvim-web-devicons credit after the leading comment lines of a theme file, once.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $lines = [System.IO.File]::ReadAllLines($Path)
    if ($lines -contains $script:CreditLine) { return }
    $headerCount = 0
    while ($headerCount -lt $lines.Count -and $lines[$headerCount] -match '^\s*//') { $headerCount++ }
    $updated = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $headerCount; $i++) { $updated.Add($lines[$i]) }
    $updated.Add($script:CreditLine)
    for ($i = $headerCount; $i -lt $lines.Count; $i++) { $updated.Add($lines[$i]) }
    [System.IO.File]::WriteAllText($Path, ($updated -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Invoke-DeviconsApply {
    # Writes the approved entries into the icon theme and the three color themes.
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Comparison,

        [Parameter(Mandatory)]
        [string]$ThemesPath,

        [Parameter(Mandatory)]
        [string]$DecisionsPath,

        [string]$SetThemeEntryPath = ([System.IO.Path]::Combine($PSScriptRoot, 'Set-ThemeEntry.ps1'))
    )

    $decisions = Read-JsoncFile -Path $DecisionsPath
    $exclude = [System.Collections.Generic.HashSet[string]]::new([string[]]@($decisions['exclude']), [System.StringComparer]::OrdinalIgnoreCase)
    $adopt = [System.Collections.Generic.HashSet[string]]::new([string[]]@($decisions['adopt']), [System.StringComparer]::OrdinalIgnoreCase)
    $manualColors = @{}
    if ($decisions['colors']) { foreach ($key in $decisions['colors'].Keys) { $manualColors[$key] = $decisions['colors'][$key].TrimStart('#').ToUpperInvariant() } }

    $iconEntries = @{ names = @{}; extensions = @{} }
    $colorEntries = @{}
    foreach ($theme in 'default', 'light', 'dracula') { $colorEntries[$theme] = @{ names = @{}; extensions = @{} } }
    $setColor = {
        param([string]$Section, [string]$Key, [string]$Hex, [string[]]$Themes)
        foreach ($theme in $Themes) {
            $colorEntries[$theme][$Section][$Key] = switch ($theme) {
                'light' { ConvertTo-LightColor -Hex $Hex }
                'dracula' { ConvertTo-DraculaColor -Hex $Hex }
                default { $Hex }
            }
        }
    }

    # A theme can already color a key that has no icon yet; that color is an existing mapping and stays.
    $currentColors = @{}
    foreach ($theme in 'default', 'light', 'dracula') { $currentColors[$theme] = (Read-JsoncFile -Path ([System.IO.Path]::Combine($ThemesPath, 'colors', "$theme.jsonc")))['files'] }
    foreach ($item in $Comparison.New) {
        if ($exclude.Contains($item.Key) -or $exclude.Contains("group:$($item.Group)")) { continue }
        $iconEntries[$item.Section][$item.Key] = $item.Glyph
        $uncolored = @(foreach ($theme in 'default', 'light', 'dracula') {
                $map = if ($currentColors[$theme]) { $currentColors[$theme][$item.Section] }
                if (-not (Find-ThemeKey -Map $map -Key $item.Key)) { $theme }
            })
        if ($uncolored.Count -gt 0) { & $setColor $item.Section $item.Key $item.Color $uncolored }
    }
    foreach ($item in $Comparison.Different) {
        if (-not $adopt.Contains($item.CurrentKey)) { continue }
        $iconEntries[$item.Section][$item.CurrentKey] = $item.Glyph
        & $setColor $item.Section $item.CurrentKey $item.Color @('default', 'light', 'dracula')
    }
    foreach ($item in $Comparison.MissingColor) {
        $hex = if ($item.ReferenceColor) { $item.ReferenceColor } elseif ($manualColors.ContainsKey($item.Key)) { $manualColors[$item.Key] } else { $null }
        if (-not $hex) { continue }
        foreach ($theme in $item.MissingIn) {
            if (-not $colorEntries[$theme][$item.Section].ContainsKey($item.Key)) { & $setColor $item.Section $item.Key $hex @($theme) }
        }
    }

    $written = [pscustomobject]@{ Icons = 0; Colors = 0 }
    $targets = @(@{ Path = [System.IO.Path]::Combine($ThemesPath, 'icons', 'default.jsonc'); Entries = $iconEntries; Kind = 'Icons' })
    foreach ($theme in 'default', 'light', 'dracula') { $targets += @{ Path = [System.IO.Path]::Combine($ThemesPath, 'colors', "$theme.jsonc"); Entries = $colorEntries[$theme]; Kind = 'Colors' } }
    foreach ($target in $targets) {
        $changed = $false
        foreach ($section in 'names', 'extensions') {
            $entries = $target.Entries[$section]
            if ($entries.Count -eq 0) { continue }
            & $SetThemeEntryPath -Path $target.Path -Section "files.$section" -Entries $entries
            $written.($target.Kind) += $entries.Count
            $changed = $true
        }
        if ($changed) { Add-ThemeCreditLine -Path $target.Path }
    }
    $written
}

Export-ModuleMember -Function Confirm-DeviconsData, Read-DeviconsFile, Get-NerdGlyphIndex, Select-GlyphName, Get-ContrastWithWhite, ConvertTo-Hsl, ConvertTo-LightColor, ConvertTo-DraculaColor, Get-DeviconsComparison, Write-DeviconsReport, Invoke-DeviconsApply
