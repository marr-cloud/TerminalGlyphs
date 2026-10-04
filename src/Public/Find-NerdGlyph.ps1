function Find-NerdGlyph {
    <#
    .SYNOPSIS
        Searches the Nerd Fonts 3.5.1 glyph names to use in your TerminalGlyphs config.
    .PARAMETER Name
        Part of a glyph name (for example cloudflare) or a wildcard pattern (nf-dev-*).
    .EXAMPLE
        Find-NerdGlyph cloudflare
    .EXAMPLE
        Find-NerdGlyph 'nf-md-folder_*'
    .OUTPUTS
        TerminalGlyphs.NerdGlyph
    #>
    [OutputType('TerminalGlyphs.NerdGlyph')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $pattern = if ([WildcardPattern]::ContainsWildcardCharacters($Name)) { $Name } else { "*$Name*" }
    $map = Get-FullGlyphMap
    foreach ($glyphName in ($map.Keys | Where-Object { $_ -like $pattern } | Sort-Object)) {
        $glyph = $map[$glyphName]
        [pscustomobject]@{
            PSTypeName = 'TerminalGlyphs.NerdGlyph'
            Name       = $glyphName
            Glyph      = $glyph
            CodePoint  = 'U+{0:X4}' -f [char]::ConvertToUtf32($glyph, 0)
        }
    }
}
