<#
.SYNOPSIS
    Rehearses publishing: publishes the built module to a temporary local repository and imports it back.
.DESCRIPTION
    Nothing is installed: the module is saved to a temporary folder. Registering the temporary repository, publishing,
    saving and importing run in a child pwsh, so every file handle is released when it exits and the temporary folder
    can always be removed. The temporary repository is always unregistered. Run ./build.ps1 first.
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
[System.IO.Directory]::CreateDirectory($work) | Out-Null
# Paths reach the child through environment variables, so quotes or spaces in them cannot break its command.
$env:TERMINALGLYPHS_REHEARSAL_BUILT = $built
$env:TERMINALGLYPHS_REHEARSAL_WORK = $work
$env:TERMINALGLYPHS_REHEARSAL_VERSION = $version
$env:TERMINALGLYPHS_REHEARSAL_REPOSITORY = "TerminalGlyphsRehearsal$([guid]::NewGuid().ToString('N'))"
$rehearsal = {
    $ErrorActionPreference = 'Stop'
    $feed = [System.IO.Path]::Combine($env:TERMINALGLYPHS_REHEARSAL_WORK, 'feed')
    $saved = [System.IO.Path]::Combine($env:TERMINALGLYPHS_REHEARSAL_WORK, 'saved')
    [System.IO.Directory]::CreateDirectory($feed) | Out-Null
    [System.IO.Directory]::CreateDirectory($saved) | Out-Null
    Register-PSResourceRepository -Name $env:TERMINALGLYPHS_REHEARSAL_REPOSITORY -Uri $feed -Trusted
    try {
        Publish-PSResource -Path $env:TERMINALGLYPHS_REHEARSAL_BUILT -Repository $env:TERMINALGLYPHS_REHEARSAL_REPOSITORY
        Save-PSResource -Name 'TerminalGlyphs' -Version $env:TERMINALGLYPHS_REHEARSAL_VERSION -Repository $env:TERMINALGLYPHS_REHEARSAL_REPOSITORY -Path $saved -TrustRepository
        $savedManifest = [System.IO.Path]::Combine($saved, 'TerminalGlyphs', $env:TERMINALGLYPHS_REHEARSAL_VERSION, 'TerminalGlyphs.psd1')
        (Import-Module -Name $savedManifest -PassThru).ExportedFunctions.Count
    } finally {
        Unregister-PSResourceRepository -Name $env:TERMINALGLYPHS_REHEARSAL_REPOSITORY -ErrorAction Ignore
    }
}
try {
    $count = @(& ([Environment]::ProcessPath) -NoProfile -NonInteractive -Command $rehearsal)[-1]
    if ($LASTEXITCODE -ne 0 -or [int]$count -ne $manifest.FunctionsToExport.Count) {
        throw "The published module exported $count functions; expected $($manifest.FunctionsToExport.Count)."
    }
    Write-Host "Publish rehearsal OK: TerminalGlyphs $version exports $count functions."
} finally {
    Remove-Item -Path 'Env:TERMINALGLYPHS_REHEARSAL_*' -ErrorAction Ignore
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction Ignore
    if ([System.IO.Directory]::Exists($work)) { Write-Warning -Message "Could not remove $work" }
}
