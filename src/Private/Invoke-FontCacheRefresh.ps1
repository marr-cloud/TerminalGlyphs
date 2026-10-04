function Invoke-FontCacheRefresh {
    # Rebuilds the fontconfig cache of the given folders on Linux. Returns $false when fc-cache is not installed or fails.
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Directory
    )

    $fcCache = Get-Command -Name 'fc-cache' -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $fcCache) { return $false }
    $existing = @($Directory | Where-Object { $_ -and [System.IO.Directory]::Exists($_) })
    if ($existing.Count -eq 0) { return $true }
    & $fcCache.Source -f @existing | Out-Null
    $LASTEXITCODE -eq 0
}
