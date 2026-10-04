function Select-GlyphThemeName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Requested,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Available,

        [Parameter(Mandatory)]
        [string]$Setting,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if ($null -eq $Requested) { return 'default' }
    if ($Requested -is [string]) {
        $match = @($Available.Keys | Where-Object { $_ -eq $Requested })
        if ($match.Count -gt 0) { return [string]$match[0] }
    }
    Write-GlyphWarning -Message "$($ConfigPath): unknown $Setting '$Requested', using 'default'."
    'default'
}
