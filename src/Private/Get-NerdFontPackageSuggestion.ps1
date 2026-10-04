function Get-NerdFontPackageSuggestion {
    <#
    .SYNOPSIS
        Suggests up to five release packages for a font name that Resolve-NerdFontPackage did not accept.
    .DESCRIPTION
        First the packages whose name or font name starts the given name (Terminus TTF -> Terminus, MonaspiceNe ->
        Monaspace), then, for names of three or more characters, the packages or font names that contain its first
        four characters (Caskaydia -> CascadiaCode, CascadiaMono). Hyphens are ignored (iA Writer -> iA-Writer).
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

    $key = (ConvertTo-NerdFontKey -Name $Name).Replace('-', '')
    if (-not $key) { return }
    $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase
    $suggestions = [System.Collections.Generic.List[string]]::new()
    $add = { param([string]$Package) if ($suggestions.Count -lt 5 -and -not $suggestions.Contains($Package)) { $suggestions.Add($Package) } }
    # Package names and font names, longest first, without hyphens: iA-Writer is typed as "iA Writer".
    $names = foreach ($prefix in $PackageMap.Keys) {
        [pscustomobject]@{ Name = $prefix.Replace('-', ''); Package = $PackageMap[$prefix] }
        [pscustomobject]@{ Name = $PackageMap[$prefix].Replace('-', ''); Package = $PackageMap[$prefix] }
    }
    foreach ($entry in ($names | Sort-Object -Property { $_.Name.Length } -Descending)) {
        if ($entry.Name.Length -ge 2 -and $key.StartsWith($entry.Name, $ignoreCase)) { & $add $entry.Package }
    }
    if ($key.Length -ge 3) {
        $stem = $key.Substring(0, [Math]::Min(4, $key.Length))
        foreach ($entry in ($names | Sort-Object -Property Name)) {
            if ($entry.Name.Contains($stem, $ignoreCase)) { & $add $entry.Package }
        }
    }
    $suggestions
}
