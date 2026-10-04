function ConvertTo-NerdFontKey {
    # Turns a font name as typed (JetBrainsMono Nerd Font Mono, MesloLGS NF) into the form used in file names
    # (JetBrainsMono, MesloLGS): no spaces and no Nerd Font / NF suffix.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    ($Name -replace '\s', '') -replace '(?i)(NerdFont(Mono|Propo)?|NF[MP]?)$', ''
}
