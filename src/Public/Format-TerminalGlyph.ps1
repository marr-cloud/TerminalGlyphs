function Format-TerminalGlyph {
    <#
    .SYNOPSIS
        Prefixes a file or folder name with its Nerd Font icon and color.
    .DESCRIPTION
        Used by the TerminalGlyphs view of Get-ChildItem. Resolves the icon and color with the active themes
        and your config. Never throws: if anything goes wrong, it returns the plain name.
    .PARAMETER InputObject
        The file or folder to format.
    .EXAMPLE
        Get-ChildItem
        TerminalGlyphs formats every item automatically.
    .EXAMPLE
        Get-Item ./go.mod | Format-TerminalGlyph
    .INPUTS
        System.IO.FileSystemInfo
    .OUTPUTS
        System.String
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileSystemInfo]$InputObject
    )

    process {
        try {
            Initialize-TerminalGlyph
            $resolved = Resolve-TerminalGlyph -Name $InputObject.Name -Directory:($InputObject -is [System.IO.DirectoryInfo]) -LinkType ([string]$InputObject.LinkType)
            $text = if ($resolved.Icon) { "$($resolved.Icon)  $($InputObject.Name)" } else { $InputObject.Name }
            if ($InputObject.LinkTarget) { $text = "$text $($script:TGState.Arrow) $($InputObject.LinkTarget)" }
            if ($resolved.Color -and $PSStyle.OutputRendering -ne 'PlainText') {
                "$($resolved.Color)$text$($PSStyle.Reset)"
            } else {
                $text
            }
        } catch {
            $InputObject.Name
        }
    }
}
