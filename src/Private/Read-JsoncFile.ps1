function Read-JsoncFile {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $text = [System.IO.File]::ReadAllText($fullPath)
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "'$fullPath' is empty."
    }
    $value = ConvertFrom-Json -InputObject $text -AsHashtable -Depth 32 -ErrorAction Stop
    if ($value -isnot [System.Collections.IDictionary]) {
        throw "'$fullPath' must contain a JSON object at the root."
    }
    $value
}
