function Read-UserConfig {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not [System.IO.File]::Exists($fullPath)) { return $null }
    try {
        Read-JsoncFile -Path $fullPath
    } catch {
        Write-GlyphWarning -Message "could not read config '$fullPath', using the built-in theme: $($_.Exception.Message)"
        $null
    }
}
