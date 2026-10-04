<#
.SYNOPSIS
    Updates the Nerd Fonts installed for the current Windows user to a given release.
.DESCRIPTION
    Downloads <Family>.tar.xz from the ryanoasis/nerd-fonts GitHub release and replaces the font files that are
    already installed in %LOCALAPPDATA%\Microsoft\Windows\Fonts. Font files that are not installed are skipped.
    If a file is in use, it is renamed to <name>.old-nerdfont and the new file is copied in its place; the
    renamed files are deleted on the next run. Restart the apps that use the font afterwards.
.EXAMPLE
    ./tools/Install-NerdFont.ps1 -Family JetBrainsMono, FiraCode -Version 3.5.1
#>
#Requires -Version 7.4
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string[]]$Family,

    [string]$Version = '3.5.1'
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This script installs fonts for the current Windows user only.' }

$fontDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Windows', 'Fonts')
foreach ($stale in (Get-ChildItem -LiteralPath $fontDir -Filter '*.old-nerdfont' -ErrorAction SilentlyContinue)) {
    $original = $stale.FullName.Substring(0, $stale.FullName.Length - '.old-nerdfont'.Length)
    if ([System.IO.File]::Exists($original)) {
        if (-not $PSCmdlet.ShouldProcess($stale.FullName, 'Delete stale renamed font')) { continue }
        try { Remove-Item -LiteralPath $stale.FullName -Force } catch { Write-Verbose -Message "Still in use: $($stale.Name)" }
    } else {
        if (-not $PSCmdlet.ShouldProcess($stale.FullName, "Restore missing font $([System.IO.Path]::GetFileName($original))")) { continue }
        try {
            Move-Item -LiteralPath $stale.FullName -Destination $original
            Write-Warning -Message "Restored $([System.IO.Path]::GetFileName($original)) from a leftover .old-nerdfont file (a previous run did not finish)."
        } catch { Write-Verbose -Message "Could not restore: $($stale.Name)" }
    }
}

$work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "nerd-fonts-$Version-$([guid]::NewGuid())")
[System.IO.Directory]::CreateDirectory($work) | Out-Null
try {
    foreach ($name in $Family) {
        $archive = [System.IO.Path]::Combine($work, "$name.tar.xz")
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/download/v$Version/$name.tar.xz" -OutFile $archive
        $extract = [System.IO.Path]::Combine($work, $name)
        [System.IO.Directory]::CreateDirectory($extract) | Out-Null
        & ([System.IO.Path]::Combine($env:SystemRoot, 'System32', 'tar.exe')) -xf $archive -C $extract
        if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $archive" }

        $replaced = 0
        $failed = [System.Collections.Generic.List[string]]::new()
        foreach ($font in (Get-ChildItem -LiteralPath $extract -Recurse -File -Include '*.ttf', '*.otf')) {
            $target = [System.IO.Path]::Combine($fontDir, $font.Name)
            if (-not [System.IO.File]::Exists($target)) { continue }
            if (-not $PSCmdlet.ShouldProcess($target, "Replace with Nerd Fonts $Version")) { continue }
            try {
                Copy-Item -LiteralPath $font.FullName -Destination $target -Force
                $replaced++
            } catch {
                try {
                    Move-Item -LiteralPath $target -Destination "$target.old-nerdfont" -Force
                    try {
                        Copy-Item -LiteralPath $font.FullName -Destination $target
                        $replaced++
                    } catch {
                        Move-Item -LiteralPath "$target.old-nerdfont" -Destination $target -Force
                        $failed.Add($font.Name)
                    }
                } catch {
                    $failed.Add($font.Name)
                }
            }
        }
        "${name}: replaced $replaced file(s)"
        if ($failed.Count -gt 0) {
            Write-Warning -Message "${name}: $($failed.Count) file(s) could not be replaced (in use). Close the apps that use them and run again: $($failed -join ', ')"
        }
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -WhatIf:$false -ErrorAction SilentlyContinue
}
