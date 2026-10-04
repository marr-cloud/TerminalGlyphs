function Merge-GlyphConfig {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Resolve', Justification = 'Called from the $newItem script block, which the analyzer does not follow.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseLiteralInitializerForHashtable', '', Justification = 'The cache of built values must be case-sensitive, so each value keeps its own name.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [AllowNull()]
        [System.Collections.IDictionary]$Theme,

        [Parameter(Mandatory)]
        [ValidateSet('Icon', 'Color')]
        [string]$ThemeType,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [scriptblock]$Resolve,

        # Resolved values by name (glyph name, or color as RRGGBB); -Resolve is called only for names it does not have.
        [System.Collections.IDictionary]$Lookup,

        [scriptblock]$GlyphExists = { $true },

        [string]$Origin = $Source,

        [switch]$Validate
    )

    if ($null -eq $Theme) { return }
    # Built-in themes have about a thousand entries and few distinct values. Walking the dictionaries directly and
    # building each distinct value once avoids an entry object and a -Resolve call per entry (~150 ms per theme).
    $items = [hashtable]::new([System.StringComparer]::Ordinal)
    $newItem = {
        param($Value, $Name)
        $resolved = & $Resolve $Value
        if ($null -eq $resolved) { return $null }
        [pscustomobject]@{ Value = $resolved; Name = $Name; Source = $Source }
    }

    foreach ($kind in @($Theme.Keys)) {
        if ($kind -ceq 'name' -or $kind -ceq '$schema') { continue }
        $target = $Table[$kind]
        $kindValue = $Theme[$kind]
        $sections = if ($kindValue -is [System.Collections.IDictionary]) { @($kindValue.Keys) } else { @($null) }
        foreach ($section in $sections) {
            $sectionValue = if ($null -eq $section) { $kindValue } else { $kindValue[$section] }
            $pairs = if ($sectionValue -is [System.Collections.IDictionary]) {
                @($sectionValue.GetEnumerator())
            } else {
                @([pscustomobject]@{ Key = $null; Value = $sectionValue })
            }
            foreach ($pair in $pairs) {
                if ($Validate) {
                    $entry = [pscustomobject]@{ Kind = $kind; Section = $section; Key = $pair.Key; Value = $pair.Value }
                    $problem = Test-GlyphThemeEntry -Entry $entry -ThemeType $ThemeType -GlyphExists $GlyphExists
                    if ($problem) {
                        Write-GlyphWarning -Message "$($Origin): ignoring $problem"
                        continue
                    }
                }
                if ($null -eq $target -or $null -eq $section) { continue }
                $isDefault = $section -ceq 'default'
                if (-not $isDefault -and ($null -eq $pair.Key -or -not $target.ContainsKey($section))) { continue }
                $value = $pair.Value
                if ($value -is [string] -and $items.ContainsKey($value)) {
                    $item = $items[$value]
                } else {
                    $name = $value
                    if ($ThemeType -eq 'Color' -and $name -is [string]) { $name = $name.TrimStart('#').ToUpperInvariant() }
                    $item = if ($Lookup -and $name -is [string] -and $Lookup.Contains($name)) {
                        [pscustomobject]@{ Value = $Lookup[$name]; Name = $name; Source = $Source }
                    } else {
                        & $newItem $value $name
                    }
                    if ($value -is [string]) { $items[$value] = $item }
                }
                if ($null -eq $item) { continue }
                if ($isDefault) { $target['default'] = $item } else { $target[$section][$pair.Key] = $item }
            }
        }
    }
}
