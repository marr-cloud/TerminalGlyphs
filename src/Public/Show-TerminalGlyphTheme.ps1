function Show-TerminalGlyphTheme {
    <#
    .SYNOPSIS
        Previews the active icon and color themes, one line per mapping.
    .PARAMETER Kind
        Which mappings to show: files, directories or both (default).
    .EXAMPLE
        Show-TerminalGlyphTheme -Kind directories
    .OUTPUTS
        System.String
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [ValidateSet('files', 'directories')]
        [string[]]$Kind = @('directories', 'files')
    )

    Initialize-TerminalGlyph
    $plain = $PSStyle.OutputRendering -eq 'PlainText'
    foreach ($kindName in $Kind) {
        $sections = if ($kindName -eq 'files') { @('names', 'extensions') } else { @('names') }
        foreach ($section in $sections) {
            $map = $script:TGState.Icons[$kindName][$section]
            foreach ($key in ($map.Keys | Sort-Object)) {
                $sample = if ($section -eq 'extensions') { "example$key" } else { $key }
                $resolved = Resolve-TerminalGlyph -Name $sample -Directory:($kindName -eq 'directories')
                $text = '{0}  {1,-28} {2}' -f $resolved.Icon, $key, "$kindName.$section"
                if ($resolved.Color -and -not $plain) { "$($resolved.Color)$text$($PSStyle.Reset)" } else { $text }
            }
        }
    }
}
