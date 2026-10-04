<#
.SYNOPSIS
    Rehearses publishing: publishes the built module to a temporary local repository and imports it back.
.DESCRIPTION
    Nothing is installed: the module is saved to a temporary folder and imported in a child pwsh. The temporary
    repository is always unregistered and its folders removed. Run ./build.ps1 first.
.EXAMPLE
    ./build.ps1; ./tools/Test-Publish.ps1
#>
#Requires -Version 7.4
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifest = Import-PowerShellDataFile -LiteralPath ([System.IO.Path]::Combine($root, 'src', 'TerminalGlyphs.psd1'))
$version = $manifest.ModuleVersion
$built = [System.IO.Path]::Combine($root, 'out', 'TerminalGlyphs', $version)
if (-not [System.IO.Directory]::Exists($built)) { throw "Module not built: $built. Run ./build.ps1 first." }

$work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "terminalglyphs-publish-$([guid]::NewGuid())")
$feed = [System.IO.Path]::Combine($work, 'feed')
$saved = [System.IO.Path]::Combine($work, 'saved')
$repository = "TerminalGlyphsRehearsal$([guid]::NewGuid().ToString('N'))"
[System.IO.Directory]::CreateDirectory($feed) | Out-Null
[System.IO.Directory]::CreateDirectory($saved) | Out-Null
try {
    Register-PSResourceRepository -Name $repository -Uri $feed -Trusted
    Publish-PSResource -Path $built -Repository $repository
    Save-PSResource -Name 'TerminalGlyphs' -Version $version -Repository $repository -Path $saved -TrustRepository
    $savedManifest = [System.IO.Path]::Combine($saved, 'TerminalGlyphs', $version, 'TerminalGlyphs.psd1')
    $count = & ([Environment]::ProcessPath) -NoProfile -NonInteractive -Command "(Import-Module '$savedManifest' -PassThru).ExportedFunctions.Count"
    if ($LASTEXITCODE -ne 0 -or [int]$count -ne $manifest.FunctionsToExport.Count) {
        throw "The published module exported $count functions; expected $($manifest.FunctionsToExport.Count)."
    }
    Write-Host "Publish rehearsal OK: TerminalGlyphs $version exports $count functions."
} finally {
    Unregister-PSResourceRepository -Name $repository -ErrorAction Ignore
    # PSResourceGet can keep a handle on the package for a moment, so retry the cleanup.
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    for ($attempt = 1; $attempt -le 5 -and [System.IO.Directory]::Exists($work); $attempt++) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction Ignore
        if ([System.IO.Directory]::Exists($work)) { Start-Sleep -Milliseconds 500 }
    }
    if ([System.IO.Directory]::Exists($work)) { Write-Warning "Could not remove $work" }
}
