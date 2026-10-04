function Write-GlyphWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    # Each distinct problem is reported once per session (Update-TerminalGlyphConfig resets this).
    if ($script:Warned.Add($Message)) {
        Write-Warning -Message "TerminalGlyphs: $Message"
    }
}
