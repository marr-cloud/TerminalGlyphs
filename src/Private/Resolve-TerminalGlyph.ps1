function Resolve-TerminalGlyph {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [switch]$Directory,

        [string]$LinkType
    )

    $kind = if ($Directory) { 'directories' } else { 'files' }
    $icon = Find-GlyphEntry -Table $script:TGState.Icons[$kind] -Kind $kind -Name $Name -LinkType $LinkType
    $color = Find-GlyphEntry -Table $script:TGState.Colors[$kind] -Kind $kind -Name $Name -LinkType $LinkType
    [pscustomobject]@{
        Icon      = $icon.Entry.Value
        IconName  = $icon.Entry.Name
        Color     = $color.Entry.Value
        ColorName = $color.Entry.Name
        Rule      = $icon.Rule
        Source    = $icon.Entry.Source
    }
}
