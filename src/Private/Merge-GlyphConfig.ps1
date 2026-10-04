function Merge-GlyphConfig {
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

        [scriptblock]$GlyphExists = { $true },

        [string]$Origin = $Source,

        [switch]$Validate
    )

    if ($null -eq $Theme) { return }
    foreach ($entry in (Get-GlyphThemeEntry -Theme $Theme)) {
        if ($Validate) {
            $problem = Test-GlyphThemeEntry -Entry $entry -ThemeType $ThemeType -GlyphExists $GlyphExists
            if ($problem) {
                Write-GlyphWarning -Message "$($Origin): ignoring $problem"
                continue
            }
        }
        $target = $Table[$entry.Kind]
        if ($null -eq $target -or $null -eq $entry.Section) { continue }
        $resolved = & $Resolve $entry.Value
        if ($null -eq $resolved) { continue }
        $name = $entry.Value
        if ($ThemeType -eq 'Color' -and $name -is [string]) { $name = $name.TrimStart('#').ToUpperInvariant() }
        $item = [pscustomobject]@{ Value = $resolved; Name = $name; Source = $Source }
        if ($entry.Section -ceq 'default') {
            $target['default'] = $item
        } elseif ($null -ne $entry.Key -and $target.ContainsKey($entry.Section)) {
            $target[$entry.Section][$entry.Key] = $item
        }
    }
}
