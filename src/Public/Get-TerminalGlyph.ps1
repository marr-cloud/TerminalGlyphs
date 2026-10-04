function Get-TerminalGlyph {
    <#
    .SYNOPSIS
        Shows which icon and color TerminalGlyphs uses for a file or folder, and why.
    .DESCRIPTION
        Resolves the icon and color with the active themes and your config, and reports the rule that matched
        (for example files.names[go.mod]) and where it came from (theme:<name> or user-config).
    .PARAMETER Path
        Path to a file or folder. Supports wildcards.
    .PARAMETER LiteralPath
        Path used exactly as typed. Objects from Get-ChildItem bind here through PSPath.
    .EXAMPLE
        Get-TerminalGlyph ./go.mod
    .EXAMPLE
        Get-ChildItem | Get-TerminalGlyph
    .OUTPUTS
        TerminalGlyphs.GlyphInfo
    #>
    [OutputType('TerminalGlyphs.GlyphInfo')]
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]]$LiteralPath
    )

    begin {
        Initialize-TerminalGlyph
    }

    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'Path') {
            Get-Item -Path $Path -Force
        } else {
            Get-Item -LiteralPath $LiteralPath -Force
        }
        foreach ($item in $items) {
            if ($item -isnot [System.IO.FileSystemInfo]) { continue }
            $resolved = Resolve-TerminalGlyph -Name $item.Name -Directory:($item -is [System.IO.DirectoryInfo]) -LinkType ([string]$item.LinkType)
            [pscustomobject]@{
                PSTypeName = 'TerminalGlyphs.GlyphInfo'
                Name       = $item.Name
                Icon       = $resolved.Icon
                IconName   = $resolved.IconName
                Color      = $resolved.ColorName
                Rule       = $resolved.Rule
                Source     = $resolved.Source
            }
        }
    }
}
