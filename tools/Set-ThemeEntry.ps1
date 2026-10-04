<#
.SYNOPSIS
    Adds or replaces entries in a TerminalGlyphs theme file (.jsonc).
.DESCRIPTION
    Keeps the leading comment lines, sorts the keys of the edited section and removes keys that differ
    only in case from the new ones (lookups are case-insensitive).
.EXAMPLE
    ./tools/Set-ThemeEntry.ps1 -Path themes/icons/default.jsonc -Section files.names -Entries @{ 'go.mod' = 'nf-dev-go' }
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateSet('files.names', 'files.extensions', 'files.links', 'directories.names', 'directories.links')]
    [string]$Section,

    [Parameter(Mandatory)]
    [hashtable]$Entries
)

$ErrorActionPreference = 'Stop'
$fullPath = (Resolve-Path -LiteralPath $Path).ProviderPath
$lines = [System.IO.File]::ReadAllLines($fullPath)
$headerCount = 0
while ($headerCount -lt $lines.Count -and $lines[$headerCount] -match '^\s*//') { $headerCount++ }
$header = if ($headerCount -gt 0) { @($lines[0..($headerCount - 1)]) } else { @() }
$body = ($lines | Select-Object -Skip $headerCount) -join "`n"
$theme = ConvertFrom-Json -InputObject $body -AsHashtable -Depth 32

$kind, $sectionName = $Section.Split('.')
if (-not $theme.Contains($kind)) { $theme[$kind] = [ordered]@{} }
if (-not $theme[$kind].Contains($sectionName)) { $theme[$kind][$sectionName] = [ordered]@{} }
$map = $theme[$kind][$sectionName]
foreach ($key in $Entries.Keys) {
    foreach ($old in @($map.Keys | Where-Object { $_ -eq $key -and $_ -cne $key })) { $map.Remove($old) }
    $map[$key] = $Entries[$key]
}
$sorted = [ordered]@{}
foreach ($key in ($map.Keys | Sort-Object { $_.ToLowerInvariant() }, { $_ })) { $sorted[$key] = $map[$key] }
$theme[$kind][$sectionName] = $sorted

if ($PSCmdlet.ShouldProcess($fullPath, "Set $($Entries.Count) entries in $Section")) {
    $json = $theme | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($fullPath, ((@($header) + $json) -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}
