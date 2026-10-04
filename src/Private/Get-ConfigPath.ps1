function Get-ConfigPath {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    if ($env:TERMINALGLYPHS_CONFIG) { return $env:TERMINALGLYPHS_CONFIG }
    $base = if ($env:XDG_CONFIG_HOME) {
        $env:XDG_CONFIG_HOME
    } else {
        [System.IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.config')
    }
    [System.IO.Path]::Combine($base, 'terminalglyphs', 'config.jsonc')
}
