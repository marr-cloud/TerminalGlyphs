function Resolve-NerdFontPackage {
    <#
    .SYNOPSIS
        Returns the Nerd Fonts release package for a package or font name, or nothing if there is none.
    .DESCRIPTION
        Accepts the release package (CascadiaCode), the font name used in file names (CaskaydiaCove) and the name shown
        in terminal settings (JetBrainsMono Nerd Font Mono, MesloLGS NF), case-insensitively. JetBrainsMonoNL and the
        Meslo LGS/LGM/LGL (DZ) variants belong to the package of their family.
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

    $key = ($Name -replace '\s', '') -replace '(?i)(NerdFont(Mono|Propo)?|NF[MP]?)$', ''
    if (-not $key) { return }
    foreach ($package in $PackageMap.Values) {
        if ($package -eq $key) { return $package }
    }
    foreach ($prefix in $PackageMap.Keys) {
        if ($prefix -eq $key) { return $PackageMap[$prefix] }
    }
    foreach ($prefix in ($PackageMap.Keys | Sort-Object -Property Length -Descending)) {
        if ($key.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and $key.Substring($prefix.Length) -match '^(?i)(NL|[SML](DZ)?)$') {
            return $PackageMap[$prefix]
        }
    }
}
