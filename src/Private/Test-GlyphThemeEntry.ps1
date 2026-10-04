function Test-GlyphThemeEntry {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Entry,

        [Parameter(Mandatory)]
        [ValidateSet('Icon', 'Color')]
        [string]$ThemeType,

        [scriptblock]$GlyphExists = { $true }
    )

    $where = if ($null -eq $Entry.Section) {
        "$($Entry.Kind)"
    } elseif ($null -eq $Entry.Key) {
        "$($Entry.Kind).$($Entry.Section)"
    } else {
        "$($Entry.Kind).$($Entry.Section)[$($Entry.Key)]"
    }

    if ($Entry.Kind -cnotin 'files', 'directories') { return "unknown section '$($Entry.Kind)'" }
    if ($null -eq $Entry.Section) { return "'$where' must be an object" }

    $sections = if ($Entry.Kind -ceq 'files') { 'names', 'extensions', 'links', 'default' } else { 'names', 'links', 'default' }
    if ($Entry.Section -cnotin $sections) { return "unknown section '$where'" }

    if ($Entry.Section -ceq 'default') {
        if ($null -ne $Entry.Key) { return "'$where' must be a string" }
    } elseif ($null -eq $Entry.Key) {
        return "'$where' must be an object"
    }

    if ($Entry.Section -ceq 'links' -and $Entry.Key -cnotin 'symlink', 'junction') { return "unknown link type at '$where'" }
    if ($Entry.Section -ceq 'extensions' -and -not $Entry.Key.StartsWith('.')) { return "extension must start with '.' at '$where'" }
    if ($Entry.Value -isnot [string]) { return "value at '$where' must be a string" }

    if ($ThemeType -eq 'Icon') {
        if (-not (& $GlyphExists $Entry.Value)) { return "unknown glyph '$($Entry.Value)' at '$where'" }
    } elseif ($Entry.Value -notmatch '^#?[0-9A-Fa-f]{6}$') {
        return "invalid color '$($Entry.Value)' at '$where'"
    }
}
