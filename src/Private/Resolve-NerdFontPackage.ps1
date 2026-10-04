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

    $key = ConvertTo-NerdFontKey -Name $Name
    if (-not $key) { return }
    foreach ($package in $PackageMap.Values) {
        if ($package -eq $key) { return $package }
    }
    foreach ($prefix in $PackageMap.Keys) {
        if ($prefix -eq $key) { return $PackageMap[$prefix] }
    }
    # Nerd Fonts 3.5.1 families named after their package plus a variant suffix: JetBrainsMonoNL, MesloLGS/LGM/LGL
    # (with or without DZ), OverpassM and OpenDyslexicM.
    $variants = @{ JetBrainsMono = '^(?i)NL$'; MesloLG = '^(?i)[SML](DZ)?$'; Overpass = '^(?i)M$'; OpenDyslexic = '^(?i)M$' }
    foreach ($prefix in $variants.Keys) {
        if ($PackageMap.Contains($prefix) -and $key.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and $key.Substring($prefix.Length) -match $variants[$prefix]) {
            return $PackageMap[$prefix]
        }
    }
}
