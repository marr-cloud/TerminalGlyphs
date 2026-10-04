function Get-NerdFontInstallation {
    <#
    .SYNOPSIS
        Groups the Nerd Font files in a folder by release package and reports which ones are outdated.
    .DESCRIPTION
        The package of a file is found from the part of its name before "NerdFont", using the longest matching
        prefix in -PackageMap (JetBrainsMonoNL and JetBrainsMono both belong to JetBrainsMono). Files without a
        readable Nerd Fonts version count as outdated.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FontDirectory,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PackageMap,

        [Parameter(Mandatory)]
        [version]$MinimumVersion
    )

    if (-not [System.IO.Directory]::Exists($FontDirectory)) { return }
    $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase
    $prefixes = @($PackageMap.Keys | Sort-Object -Property Length -Descending)
    $families = [ordered]@{}
    $files = Get-ChildItem -LiteralPath $FontDirectory -Recurse -File -ErrorAction Ignore |
        Where-Object { $_.Extension -in '.ttf', '.otf' -and $_.Name.Contains('NerdFont', $ignoreCase) } |
        Sort-Object -Property FullName
    foreach ($file in $files) {
        $stem = $file.Name.Substring(0, $file.Name.IndexOf('NerdFont', $ignoreCase))
        $prefix = $prefixes | Where-Object { $stem.StartsWith($_, $ignoreCase) } | Select-Object -First 1
        $package = if ($prefix) { $PackageMap[$prefix] } else { $null }
        $key = if ($package) { $package } else { "?$stem" }
        if (-not $families.Contains($key)) {
            $families[$key] = [pscustomobject]@{
                PSTypeName = 'TerminalGlyphs.NerdFontFamily'
                Name       = if ($package) { $package } else { $stem }
                Package    = $package
                Files      = [System.Collections.Generic.List[string]]::new()
                Version    = $null
                IsOutdated = $false
            }
        }
        $entry = $families[$key]
        $entry.Files.Add($file.FullName)
        $info = Read-FontInfo -Path $file.FullName
        if ($null -eq $info -or $null -eq $info.Version) {
            $entry.IsOutdated = $true
            continue
        }
        if ($null -eq $entry.Version -or $info.Version -lt $entry.Version) { $entry.Version = $info.Version }
        if ($info.Version -lt $MinimumVersion) { $entry.IsOutdated = $true }
    }
    $families.Values
}
