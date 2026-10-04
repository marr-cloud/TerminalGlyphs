function Get-NerdFontPackageSuggestion {
    <#
    .SYNOPSIS
        Suggests up to five release packages for a font name that Resolve-NerdFontPackage did not accept.
    .DESCRIPTION
        First the packages whose font name starts the given name (MonaspiceNe -> Monaspace), then the packages or font
        names that contain its first four characters (Caskaydia -> CascadiaCode, CascadiaMono).
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PackageMap
    )

    $key = ConvertTo-NerdFontKey -Name $Name
    if (-not $key) { return }
    $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase
    $stem = $key.Substring(0, [Math]::Min(4, $key.Length))
    $suggestions = [System.Collections.Generic.List[string]]::new()
    $add = { param([string]$Package) if ($suggestions.Count -lt 5 -and -not $suggestions.Contains($Package)) { $suggestions.Add($Package) } }
    foreach ($prefix in ($PackageMap.Keys | Sort-Object -Property Length -Descending)) {
        if ($prefix.Length -ge 2 -and $key.StartsWith($prefix, $ignoreCase)) { & $add $PackageMap[$prefix] }
    }
    foreach ($prefix in ($PackageMap.Keys | Sort-Object)) {
        if ($prefix.Contains($stem, $ignoreCase) -or $PackageMap[$prefix].Contains($stem, $ignoreCase)) { & $add $PackageMap[$prefix] }
    }
    $suggestions
}
