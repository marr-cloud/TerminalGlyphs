function Invoke-FontCacheRefresh {
    # Rebuilds the fontconfig cache on Linux. Returns $false when fc-cache is not installed or fails.
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )

    $fcCache = Get-Command -Name 'fc-cache' -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $fcCache) { return $false }
    & $fcCache.Source -f $Directory | Out-Null
    $LASTEXITCODE -eq 0
}
