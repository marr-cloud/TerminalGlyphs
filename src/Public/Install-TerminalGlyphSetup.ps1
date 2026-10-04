function Install-TerminalGlyphSetup {
    <#
    .SYNOPSIS
        Installs or updates Nerd Fonts and makes your PowerShell profile import TerminalGlyphs.
    .DESCRIPTION
        Updates the Nerd Fonts in your user font folder that are older than the version TerminalGlyphs is built for
        (3.5.1), installs the packages in -Family (or JetBrainsMono if you have no Nerd Font), and replaces
        "Import-Module Terminal-Icons" in your profile, keeping a backup. Fonts are installed for the current user
        only, without admin rights. Your terminal settings are not changed: choose the font there afterwards.
        Nerd Fonts 2.x files are not changed: remove them first, then run the command again. Nerd Fonts installed
        for all users are reported but not changed.

        Each step runs even if another one fails, and the command returns one result per step. On Windows, fonts
        that were in use are replaced after you restart Windows.
    .PARAMETER Family
        Nerd Fonts to install or update. Use the release package (JetBrainsMono, FiraCode, CascadiaCode, Meslo), the
        font name (CaskaydiaCove, MesloLGS) or the name shown in your terminal settings (JetBrainsMono Nerd Font Mono).
        Press Tab to list the packages.
    .PARAMETER SkipFont
        Does not install, update or clean up fonts.
    .PARAMETER SkipProfile
        Does not change your profile.
    .EXAMPLE
        Install-TerminalGlyphSetup
    .EXAMPLE
        Install-TerminalGlyphSetup -Family FiraCode -WhatIf
    .EXAMPLE
        Install-TerminalGlyphSetup -Family 'CaskaydiaCove Nerd Font Mono'
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ArgumentCompleter({
                # Completers receive (command, parameter, word to complete, ...). A quoted word arrives as 'Casc'.
                $WordToComplete = ([string]$args[2]).Trim([char[]]"'`"")
                # The module that owns the command in use, even when several versions are loaded.
                $module = (Get-Command -Name $args[0] -CommandType Function -ErrorAction Ignore | Select-Object -First 1).Module
                if (-not $module) { return }
                $packages = & $module { (Read-NerdFontIndex)['packages'].Values } | Sort-Object -Unique
                $pattern = [System.Management.Automation.WildcardPattern]::Escape($WordToComplete) + '*'
                foreach ($package in ($packages | Where-Object { $_ -like $pattern })) {
                    [System.Management.Automation.CompletionResult]::new($package, $package, 'ParameterValue', $package)
                }
            })]
        [string[]]$Family,

        [switch]$SkipFont,

        [switch]$SkipProfile
    )

    $ErrorActionPreference = 'Stop'
    $nerdFonts = Read-NerdFontIndex
    $version = [version]$nerdFonts['version']
    $packageMap = $nerdFonts['packages']
    $requested = foreach ($name in $Family) {
        $match = Resolve-NerdFontPackage -Name $name -PackageMap $packageMap
        if (-not $match) {
            $similar = @(Get-NerdFontPackageSuggestion -Name $name -PackageMap $packageMap)
            $suggestion = if ($similar.Count -gt 0) { " Did you mean $($similar -join ', ')?" } else { ' Use a release package name such as JetBrainsMono, FiraCode, CascadiaCode, Hack or Meslo.' }
            throw "Unknown Nerd Fonts package '$name'.$suggestion Press Tab after -Family to list the packages."
        }
        $match
    }

    $newStep = {
        param([string]$Name, [string]$Status, [string]$Detail)
        [pscustomobject]@{ PSTypeName = 'TerminalGlyphs.SetupStep'; Step = $Name; Status = $Status; Detail = $Detail }
    }
    $restartNeeded = $false
    $profileChanged = $false
    $fontToChoose = $null

    if ($SkipFont) {
        & $newStep 'Fonts' 'Skipped' 'Skipped with -SkipFont'
    } else {
        $work = $null
        try {
            $location = Get-FontLocation
            if ($location.Platform -eq 'Windows') {
                try {
                    $stale = Remove-StaleFontFile -FontDirectory $location.Directory
                    if ($stale.Pending -gt 0) { $restartNeeded = $true }
                    if ($stale.Removed + $stale.Restored -gt 0) {
                        & $newStep 'Font cleanup' 'OK' ('Removed {0} replaced file(s), restored {1}' -f $stale.Removed, $stale.Restored)
                    } elseif ($stale.Pending -gt 0) {
                        & $newStep 'Font cleanup' 'Unchanged' ('{0} replaced file(s) waiting for a restart' -f $stale.Pending)
                    } else {
                        & $newStep 'Font cleanup' 'Unchanged' 'Nothing to clean up'
                    }
                } catch {
                    & $newStep 'Font cleanup' 'Error' $_.Exception.Message
                }
            }

            # Per-user folders are updated in place (Directory first; on Linux also ~/.fonts).
            $userDirectories = @($location.UserDirectory | Where-Object { $_ })
            if ($userDirectories.Count -eq 0) { $userDirectories = @($location.Directory) }
            $installed = @(Get-NerdFontInstallation -FontDirectory $userDirectories -PackageMap $packageMap -MinimumVersion $version)
            # Fonts installed for all users are only reported: changing them needs admin rights.
            $system = @(foreach ($systemDirectory in @($location.SystemDirectory | Where-Object { $_ })) {
                    Get-NerdFontInstallation -FontDirectory $systemDirectory -PackageMap $packageMap -MinimumVersion $version
                })
            foreach ($scan in @(@{ Suffix = ''; Found = $installed }, @{ Suffix = ' (all users)'; Found = $system })) {
                foreach ($legacy in ($scan.Found | Where-Object { $_.IsLegacy })) {
                    $advice = '{0} file(s) from Nerd Fonts 2.x; remove them in your system font settings, then run Install-TerminalGlyphSetup again' -f $legacy.Files.Count
                    Write-Warning -Message "TerminalGlyphs: $advice."
                    & $newStep "Font $($legacy.Name)$($scan.Suffix)" 'Skipped' $advice
                }
            }
            foreach ($unknown in ($installed | Where-Object { -not $_.Package -and -not $_.IsLegacy })) {
                Write-Warning -Message "TerminalGlyphs: $($unknown.Name) is not a Nerd Fonts $version family; it was not changed."
                & $newStep "Font $($unknown.Name)" 'Skipped' 'Unknown Nerd Fonts family'
            }
            foreach ($shared in ($system | Where-Object { -not $_.IsLegacy })) {
                $stepName = "Font $($shared.Name) (all users)"
                if ($shared.IsOutdated) {
                    $from = if ($shared.Version) { $shared.Version } else { 'unknown version' }
                    & $newStep $stepName 'Skipped' "Nerd Fonts $from installed for all users; updating it needs admin rights"
                } else {
                    & $newStep $stepName 'Unchanged' "Nerd Fonts $($shared.Version)"
                }
            }
            $plan = [ordered]@{}
            foreach ($entry in ($installed | Where-Object { $_.Package })) { $plan[$entry.Package] = $entry }
            foreach ($name in $requested) { if (-not $plan.Contains($name)) { $plan[$name] = $null } }
            if (-not $Family -and $installed.Count -eq 0 -and $system.Count -eq 0) { $plan['JetBrainsMono'] = $null }

            $changed = 0
            foreach ($package in $plan.Keys) {
                $current = $plan[$package]
                $stepName = "Font $package"
                if ($current -and -not $current.IsOutdated) {
                    & $newStep $stepName 'Unchanged' "Nerd Fonts $($current.Version)"
                    continue
                }
                $action = if ($current) {
                    $from = if ($current.Version) { $current.Version } else { 'an unknown version' }
                    "Update from $from to Nerd Fonts $version"
                } else {
                    "Install Nerd Fonts $version"
                }
                if (-not $PSCmdlet.ShouldProcess("$package Nerd Font", $action)) {
                    & $newStep $stepName 'Skipped' $action
                    continue
                }
                try {
                    if (-not $work) {
                        $work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "terminalglyphs-$([guid]::NewGuid())")
                        [System.IO.Directory]::CreateDirectory($work) | Out-Null
                    }
                    $files = @(Save-NerdFontRelease -Package $package -Version $version.ToString() -ExpectedHash $nerdFonts['archives'][$package] -Destination $work)
                    $target = if ($location.Platform -eq 'Linux') { [System.IO.Path]::Combine($location.Directory, 'NerdFonts', $package) } else { $location.Directory }
                    $installedFiles = @()
                    if ($current) { $installedFiles = [string[]]$current.Files }
                    $result = Install-NerdFontFile -SourceFile $files -TargetDirectory $target -Platform $location.Platform -InstalledFile $installedFiles -UpdateOnly:([bool]$current)
                    $fileChanges = $result.Added.Count + $result.Replaced + $result.Renamed
                    $changed += $fileChanges
                    if ($result.Renamed -gt 0) { $restartNeeded = $true }
                    if (-not $current -and -not $fontToChoose -and $result.Added.Count -gt 0) {
                        $mono = $result.Added | Where-Object { [System.IO.Path]::GetFileName($_) -like '*NerdFontMono-Regular.*' } | Select-Object -First 1
                        $info = if ($mono) { Read-FontInfo -Path $mono }
                        $fontToChoose = if ($info -and $info.Family) { $info.Family } else { "$package Nerd Font Mono" }
                    }
                    $detail = '{0}: {1} added, {2} replaced' -f $action, $result.Added.Count, ($result.Replaced + $result.Renamed)
                    if ($result.Failed.Count -gt 0) {
                        $problem = if ($location.Platform -eq 'Windows') { 'in use could not be replaced, close the apps that use them and run again' } else { 'could not be replaced (check permissions)' }
                        & $newStep $stepName 'Error' ('{0}; {1} file(s) {2}' -f $detail, $result.Failed.Count, $problem)
                    } elseif ($current -and $fileChanges -eq 0) {
                        & $newStep $stepName 'Error' ('{0}: none of the installed files are in the {1} package' -f $action, $package)
                    } else {
                        & $newStep $stepName 'OK' $detail
                    }
                } catch {
                    & $newStep $stepName 'Error' $_.Exception.Message
                }
            }
            if ($changed -gt 0 -and $location.Platform -eq 'Linux' -and -not (Invoke-FontCacheRefresh -Directory $userDirectories)) {
                Write-Warning -Message 'TerminalGlyphs: fc-cache was not found or failed; sign out and back in to see the new fonts.'
            }
        } catch {
            & $newStep 'Fonts' 'Error' $_.Exception.Message
        } finally {
            if ($work) { Remove-Item -LiteralPath $work -Recurse -Force -WhatIf:$false -Confirm:$false -ErrorAction Ignore }
        }
    }

    if ($SkipProfile) {
        & $newStep 'Profile' 'Skipped' 'Skipped with -SkipProfile'
    } else {
        try {
            $profileResult = Update-ProfileImport
            & $newStep 'Profile' $profileResult.Status ('{0}: {1}' -f $profileResult.Path, $profileResult.Detail)
            $profileChanged = $profileResult.Status -eq 'OK'
        } catch {
            & $newStep 'Profile' 'Error' $_.Exception.Message
        }
    }

    if ($fontToChoose) { Write-Host "Set your terminal font to '$fontToChoose'." }
    if ($restartNeeded) { Write-Host 'Restart Windows to finish replacing fonts that were in use; until then, apps keep the old version. Then run Install-TerminalGlyphSetup again to remove the replaced files.' }
    if ($profileChanged) { Write-Host 'Open a new terminal to load TerminalGlyphs.' }
}
