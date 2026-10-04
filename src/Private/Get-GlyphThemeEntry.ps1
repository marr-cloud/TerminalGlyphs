function Get-GlyphThemeEntry {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Theme
    )

    foreach ($kind in @($Theme.Keys)) {
        if ($kind -ceq 'name' -or $kind -ceq '$schema') { continue }
        $kindValue = $Theme[$kind]
        if ($kindValue -isnot [System.Collections.IDictionary]) {
            [pscustomobject]@{ Kind = $kind; Section = $null; Key = $null; Value = $kindValue }
            continue
        }
        foreach ($section in @($kindValue.Keys)) {
            $sectionValue = $kindValue[$section]
            if ($sectionValue -is [System.Collections.IDictionary]) {
                foreach ($key in @($sectionValue.Keys)) {
                    [pscustomobject]@{ Kind = $kind; Section = $section; Key = $key; Value = $sectionValue[$key] }
                }
            } else {
                [pscustomobject]@{ Kind = $kind; Section = $section; Key = $null; Value = $sectionValue }
            }
        }
    }
}
