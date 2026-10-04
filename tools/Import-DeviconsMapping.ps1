<#
.SYNOPSIS
    Proposes and applies file icons and colors from the vendored nvim-web-devicons data.
.DESCRIPTION
    -Report writes a Markdown report: new entries grouped by the reference's name, existing entries with another
    glyph, glyphs without a Nerd Fonts name and icons without a color. -Apply writes the entries allowed by the
    decisions file into themes/icons/default.jsonc and the three color themes; existing entries change only when they
    are listed in "adopt".
.EXAMPLE
    ./tools/Import-DeviconsMapping.ps1 -Report docs/mappings/devicons-0.3.0.md
.EXAMPLE
    ./tools/Import-DeviconsMapping.ps1 -Apply
#>
#Requires -Version 7.4
[CmdletBinding(DefaultParameterSetName = 'Report')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Report')]
    [string]$Report,

    [Parameter(Mandatory, ParameterSetName = 'Apply')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'Apply')]
    [string]$Decisions = ([System.IO.Path]::Combine($PSScriptRoot, 'devicons-decisions.jsonc')),

    [string]$ThemesPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'themes')),

    [string]$VendorPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'vendor', 'nvim-web-devicons')),

    [string]$GlyphNamesPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'vendor', 'nerd-fonts', 'glyphnames.json'))
)

$ErrorActionPreference = 'Stop'
# .NET resolves relative paths against the process folder, not the PowerShell location.
$resolve = { param([string]$Path) $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path) }
$ThemesPath = & $resolve $ThemesPath
$VendorPath = & $resolve $VendorPath
$GlyphNamesPath = & $resolve $GlyphNamesPath
$Decisions = & $resolve $Decisions
if ($Report) { $Report = & $resolve $Report }
Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'DeviconsMapping.psm1')) -Force
$comparison = Get-DeviconsComparison -VendorPath $VendorPath -GlyphNamesPath $GlyphNamesPath -ThemesPath $ThemesPath
if ($Apply) {
    $written = Invoke-DeviconsApply -Comparison $comparison -ThemesPath $ThemesPath -DecisionsPath $Decisions
    Write-Host "Applied $($written.Icons) icon entries and $($written.Colors) color entries."
} else {
    Write-DeviconsReport -Comparison $comparison -Path $Report
    Write-Host "Report written to $Report ($($comparison.New.Count) new, $($comparison.Different.Count) different)."
}
