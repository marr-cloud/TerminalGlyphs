function Update-TerminalGlyphConfig {
    <#
    .SYNOPSIS
        Reloads your TerminalGlyphs config without restarting the session.
    .DESCRIPTION
        Re-reads the config file and shows its validation warnings again, even if they were shown before.
        The config path is $env:TERMINALGLYPHS_CONFIG, $env:XDG_CONFIG_HOME/terminalglyphs/config.jsonc
        or ~/.config/terminalglyphs/config.jsonc.
    .EXAMPLE
        Update-TerminalGlyphConfig
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess((Get-ConfigPath), 'Reload TerminalGlyphs config')) {
        $script:Warned.Clear()
        Initialize-TerminalGlyph -Force
    }
}
