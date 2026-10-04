BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-Module (Get-BuiltManifestPath) -Force
    $fontDir = Join-Path $TestDrive 'fonts'

    function Invoke-Setup([hashtable]$Parameters = @{}) {
        $output = Install-TerminalGlyphSetup @Parameters 6>&1
        [pscustomobject]@{
            Steps = @($output | Where-Object { $_.PSObject.TypeNames -contains 'TerminalGlyphs.SetupStep' })
            Notes = @($output | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { "$_" })
        }
    }
    function Get-Step($Result, [string]$Name) { $Result.Steps | Where-Object Step -EQ $Name }
    function New-Family([string]$Package, [string]$Version, [bool]$Outdated) {
        [pscustomobject]@{
            Name       = $Package
            Package    = $Package
            Files      = [System.Collections.Generic.List[string]]@(Join-Path $fontDir "$($Package)NerdFont-Regular.ttf")
            Version    = [version]$Version
            IsOutdated = $Outdated
        }
    }
}

AfterAll {
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Install-TerminalGlyphSetup' {
    BeforeEach {
        # Never touch the real font folder, registry, network or profile.
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Windows'; Directory = $fontDir } }
        Mock -ModuleName TerminalGlyphs Remove-StaleFontFile { [pscustomobject]@{ Removed = 0; Restored = 0; Pending = 0 } }
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { }
        Mock -ModuleName TerminalGlyphs Save-NerdFontRelease { @(Join-Path $Destination $Package "$($Package)NerdFontMono-Regular.ttf") }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile {
            $names = @($SourceFile | ForEach-Object { Join-Path $TargetDirectory (Split-Path -Leaf $_) })
            [pscustomobject]@{
                Added    = [System.Collections.Generic.List[string]]@(if (-not $UpdateOnly) { $names })
                Replaced = if ($UpdateOnly) { $names.Count } else { 0 }
                Renamed  = 0
                Failed   = [System.Collections.Generic.List[string]]::new()
            }
        }
        Mock -ModuleName TerminalGlyphs Read-FontInfo { [pscustomobject]@{ FullName = 'JetBrainsMono NFM Regular'; Family = 'JetBrainsMono Nerd Font Mono'; Version = [version]'3.5.1' } }
        Mock -ModuleName TerminalGlyphs Invoke-FontCacheRefresh { $true }
        Mock -ModuleName TerminalGlyphs Update-ProfileImport { [pscustomobject]@{ Path = 'profile.ps1'; Status = 'OK'; Detail = 'Replace Import-Module Terminal-Icons with TerminalGlyphs' } }
    }

    It 'installs JetBrainsMono when there is no Nerd Font and says which font to choose' {
        $result = Invoke-Setup
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'OK'
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 1 -Exactly -ParameterFilter { $Package -eq 'JetBrainsMono' -and $Version -eq '3.5.1' }
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 1 -Exactly -ParameterFilter { -not $UpdateOnly -and $TargetDirectory -eq $fontDir -and $Platform -eq 'Windows' }
        $result.Notes | Should -Contain "Set your terminal font to 'JetBrainsMono Nerd Font Mono'."
        (Get-Step $result 'Profile').Status | Should -Be 'OK'
        $result.Notes | Should -Contain 'Open a new terminal to load TerminalGlyphs.'
    }

    It 'updates only the outdated families it finds' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true; New-Family 'Hack' '3.5.1' $false }
        $result = Invoke-Setup
        (Get-Step $result 'Font FiraCode').Status | Should -Be 'OK'
        (Get-Step $result 'Font FiraCode').Detail | Should -Match 'Update from 3\.0\.2 to Nerd Fonts 3\.5\.1'
        (Get-Step $result 'Font Hack').Status | Should -Be 'Unchanged'
        Get-Step $result 'Font JetBrainsMono' | Should -BeNullOrEmpty
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 1 -Exactly -ParameterFilter { $UpdateOnly -and $InstalledFile -contains (Join-Path $fontDir 'FiraCodeNerdFont-Regular.ttf') }
        $result.Notes | Should -Not -Contain "Set your terminal font to 'JetBrainsMono Nerd Font Mono'."
    }

    It 'installs the families in -Family next to the ones that are current' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'JetBrainsMono' '3.5.1' $false }
        $result = Invoke-Setup @{ Family = 'firacode' }
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Unchanged'
        (Get-Step $result 'Font FiraCode').Status | Should -Be 'OK'
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 1 -Exactly -ParameterFilter { $Package -ceq 'FiraCode' }
    }

    It 'does not install the default font when an unknown Nerd Font is installed' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { [pscustomobject]@{ Name = 'FooBar'; Package = $null; Files = [System.Collections.Generic.List[string]]@('x'); Version = $null; IsOutdated = $true } }
        $result = Invoke-Setup @{ WarningAction = 'SilentlyContinue' }
        (Get-Step $result 'Font FooBar').Status | Should -Be 'Skipped'
        Get-Step $result 'Font JetBrainsMono' | Should -BeNullOrEmpty
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
    }

    It 'asks to remove Nerd Fonts 2.x files instead of installing the default font' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation {
            [pscustomobject]@{ Name = 'Nerd Fonts 2.x'; Package = $null; Files = [System.Collections.Generic.List[string]]@('a.ttf', 'b.ttf'); Version = [version]'2.3.3'; IsOutdated = $true; IsLegacy = $true }
        }
        $result = Invoke-Setup @{ WarningAction = 'SilentlyContinue' }
        $advice = '2 file(s) from Nerd Fonts 2.x; remove them in your system font settings, then run Install-TerminalGlyphSetup again'
        $step = @(Get-Step $result 'Font Nerd Fonts 2.x')
        $step.Count | Should -Be 1
        $step[0].Status | Should -Be 'Skipped'
        $step[0].Detail | Should -BeExactly $advice
        $warnings = @(Install-TerminalGlyphSetup -SkipProfile 3>&1 6>$null | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 1
        "$($warnings[0])" | Should -BeLike "*$advice*"
        Get-Step $result 'Font JetBrainsMono' | Should -BeNullOrEmpty
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
    }

    Context 'with Nerd Fonts installed for all users' {
        BeforeEach {
            $systemDir = Join-Path $TestDrive 'system-fonts'
            Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Windows'; Directory = $fontDir; SystemDirectory = [string[]]@($systemDir) } }
        }

        It 'does not install the default font when a current one is installed for all users' {
            Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation -ParameterFilter { $FontDirectory -eq $systemDir } { New-Family 'JetBrainsMono' '3.5.1' $false }
            $result = Invoke-Setup
            $step = Get-Step $result 'Font JetBrainsMono (all users)'
            $step.Status | Should -Be 'Unchanged'
            $step.Detail | Should -Be 'Nerd Fonts 3.5.1'
            Get-Step $result 'Font JetBrainsMono' | Should -BeNullOrEmpty
            Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
        }

        It 'reports an outdated family for all users without changing it' {
            Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation -ParameterFilter { $FontDirectory -eq $systemDir } { New-Family 'FiraCode' '3.0.2' $true }
            Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation -ParameterFilter { $FontDirectory -eq $fontDir } { New-Family 'Hack' '3.5.1' $false }
            $result = Invoke-Setup
            $step = Get-Step $result 'Font FiraCode (all users)'
            $step.Status | Should -Be 'Skipped'
            $step.Detail | Should -Be 'Nerd Fonts 3.0.2 installed for all users; updating it needs admin rights'
            (Get-Step $result 'Font Hack').Status | Should -Be 'Unchanged'
            Get-Step $result 'Font FiraCode' | Should -BeNullOrEmpty
            Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
            Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 0
        }

        It 'reports Nerd Fonts 2.x files for all users' {
            Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation -ParameterFilter { $FontDirectory -eq $systemDir } {
                [pscustomobject]@{ Name = 'Nerd Fonts 2.x'; Package = $null; Files = [System.Collections.Generic.List[string]]@('a.ttf'); Version = $null; IsOutdated = $true; IsLegacy = $true }
            }
            $result = Invoke-Setup @{ WarningAction = 'SilentlyContinue' }
            $step = @(Get-Step $result 'Font Nerd Fonts 2.x (all users)')
            $step.Count | Should -Be 1
            $step[0].Status | Should -Be 'Skipped'
            $step[0].Detail | Should -BeExactly '1 file(s) from Nerd Fonts 2.x; remove them in your system font settings, then run Install-TerminalGlyphSetup again'
            Get-Step $result 'Font JetBrainsMono' | Should -BeNullOrEmpty
            Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
        }
    }

    It 'rejects an unknown -Family before changing anything' {
        { Install-TerminalGlyphSetup -Family 'NoSuchFont' } | Should -Throw '*Unknown Nerd Fonts package*NoSuchFont*'
        Should -Invoke -ModuleName TerminalGlyphs Get-FontLocation -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Update-ProfileImport -Times 0
    }

    It 'keeps going and removes its temporary folder when a download fails' {
        $script:Work = $null
        Mock -ModuleName TerminalGlyphs Save-NerdFontRelease { $script:Work = $Destination; throw 'network down' }
        $result = Invoke-Setup
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Error'
        (Get-Step $result 'Font JetBrainsMono').Detail | Should -Match 'network down'
        $script:Work | Should -Not -BeNullOrEmpty
        $script:Work | Should -Not -Exist
        (Get-Step $result 'Profile').Status | Should -Be 'OK'
    }

    It 'reports files that could not be replaced as an error' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile { [pscustomobject]@{ Added = [System.Collections.Generic.List[string]]::new(); Replaced = 0; Renamed = 0; Failed = [System.Collections.Generic.List[string]]@('FiraCodeNerdFont-Regular.ttf') } }
        (Get-Step (Invoke-Setup) 'Font FiraCode').Status | Should -Be 'Error'
    }

    It 'asks for a restart when a font in use was renamed or is still waiting' -ForEach @(
        @{ Case = 'renamed now'; Renamed = 1; Pending = 0 }
        @{ Case = 'pending from a previous run'; Renamed = 0; Pending = 2 }
    ) {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile { [pscustomobject]@{ Added = [System.Collections.Generic.List[string]]::new(); Replaced = 0; Renamed = $Renamed; Failed = [System.Collections.Generic.List[string]]::new() } }
        Mock -ModuleName TerminalGlyphs Remove-StaleFontFile { [pscustomobject]@{ Removed = 0; Restored = 0; Pending = $Pending } }
        $result = Invoke-Setup
        $result.Notes | Should -Contain 'Restart Windows to finish replacing fonts that were in use; until then, apps keep the old version. Then run Install-TerminalGlyphSetup again to remove the replaced files.'
    }

    It 'does not name a font to choose when the install added no file' {
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile { [pscustomobject]@{ Added = [System.Collections.Generic.List[string]]::new(); Replaced = 1; Renamed = 0; Failed = [System.Collections.Generic.List[string]]::new() } }
        $result = Invoke-Setup
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'OK'
        @($result.Notes | Where-Object { $_ -like 'Set your terminal font*' }).Count | Should -Be 0
    }

    It 'reports an update that matched none of the installed files as an error' {
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile { [pscustomobject]@{ Added = [System.Collections.Generic.List[string]]::new(); Replaced = 0; Renamed = 0; Failed = [System.Collections.Generic.List[string]]::new() } }
        $step = Get-Step (Invoke-Setup) 'Font FiraCode'
        $step.Status | Should -Be 'Error'
        $step.Detail | Should -BeExactly 'Update from 3.0.2 to Nerd Fonts 3.5.1: none of the installed files are in the FiraCode package'
    }

    It 'explains files that could not be replaced on <Platform>' -ForEach @(
        @{ Platform = 'Windows'; Expected = '*; 1 file(s) in use could not be replaced, close the apps that use them and run again' }
        @{ Platform = 'Linux'; Expected = '*; 1 file(s) could not be replaced (check permissions)' }
        @{ Platform = 'MacOS'; Expected = '*; 1 file(s) could not be replaced (check permissions)' }
    ) {
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = $Platform; Directory = $fontDir } }
        Mock -ModuleName TerminalGlyphs Get-NerdFontInstallation { New-Family 'FiraCode' '3.0.2' $true }
        Mock -ModuleName TerminalGlyphs Install-NerdFontFile { [pscustomobject]@{ Added = [System.Collections.Generic.List[string]]::new(); Replaced = 1; Renamed = 0; Failed = [System.Collections.Generic.List[string]]@('FiraCodeNerdFont-Regular.ttf') } }
        $step = Get-Step (Invoke-Setup) 'Font FiraCode'
        $step.Status | Should -Be 'Error'
        $step.Detail | Should -BeLike $Expected
    }

    It 'warns when fc-cache did not refresh the font cache' {
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Linux'; Directory = $fontDir } }
        Mock -ModuleName TerminalGlyphs Invoke-FontCacheRefresh { $false }
        $warnings = @(Install-TerminalGlyphSetup -SkipProfile 3>&1 6>$null | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 1
        "$($warnings[0])" | Should -BeLike '*fc-cache was not found or failed*'
    }

    It 'reports a cleanup error and still installs fonts' {
        Mock -ModuleName TerminalGlyphs Remove-StaleFontFile { throw 'access denied' }
        $result = Invoke-Setup
        (Get-Step $result 'Font cleanup').Status | Should -Be 'Error'
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'OK'
    }

    It 'on Linux, installs into NerdFonts/<Package> and refreshes the font cache once' {
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Linux'; Directory = $fontDir } }
        Invoke-Setup @{ Family = 'JetBrainsMono', 'Hack' } | Out-Null
        Should -Invoke -ModuleName TerminalGlyphs Remove-StaleFontFile -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 1 -Exactly -ParameterFilter { $TargetDirectory -eq (Join-Path $fontDir 'NerdFonts' 'Hack') }
        Should -Invoke -ModuleName TerminalGlyphs Invoke-FontCacheRefresh -Times 1 -Exactly
    }

    It 'skips both steps with -SkipFont and -SkipProfile' {
        $result = Invoke-Setup @{ SkipFont = $true; SkipProfile = $true }
        (Get-Step $result 'Fonts').Status | Should -Be 'Skipped'
        (Get-Step $result 'Profile').Status | Should -Be 'Skipped'
        Should -Invoke -ModuleName TerminalGlyphs Get-FontLocation -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Update-ProfileImport -Times 0
    }

    It 'downloads nothing with -WhatIf' {
        $result = Invoke-Setup @{ WhatIf = $true }
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Skipped'
        Should -Invoke -ModuleName TerminalGlyphs Save-NerdFontRelease -Times 0
        Should -Invoke -ModuleName TerminalGlyphs Install-NerdFontFile -Times 0
    }
}

Describe 'Install-TerminalGlyphSetup end to end' {
    BeforeAll {
        $script:Release = New-FakeNerdFontRelease -Root (Join-Path $TestDrive 'e2e-release') -Package 'JetBrainsMono' -FontName 'JetBrainsMonoNerdFontMono-Regular.ttf', 'JetBrainsMonoNerdFont-Regular.ttf'
    }

    BeforeEach {
        $script:Case = Join-Path $TestDrive "e2e-$([guid]::NewGuid())"
        $script:Fonts = Join-Path $script:Case 'fonts'
        $script:Installed = New-TestFont -Path (Join-Path $script:Fonts 'NerdFonts' 'JetBrainsMono' 'JetBrainsMonoNerdFontMono-Regular.ttf') -FullName 'Old' -Version 'Version 2.304;Nerd Fonts 3.0.2'
        $script:ProfilePath = Join-Path $script:Case 'profile.ps1'
        [System.IO.File]::WriteAllText($script:ProfilePath, "Import-Module Terminal-Icons`n")
        $script:SavedProfile = $global:PROFILE
        $global:PROFILE = [pscustomobject]@{ CurrentUserCurrentHost = $script:ProfilePath; CurrentUserAllHosts = $null; AllUsersCurrentHost = $null; AllUsersAllHosts = $null }
        # Linux keeps the real code path free of the registry and the Windows font API on every OS.
        Mock -ModuleName TerminalGlyphs Get-FontLocation { [pscustomobject]@{ Platform = 'Linux'; Directory = $script:Fonts } }
        Mock -ModuleName TerminalGlyphs Invoke-FontCacheRefresh { $true }
        Mock -ModuleName TerminalGlyphs Invoke-NerdFontDownload { Copy-Item -LiteralPath (Join-Path $script:Release ($Uri -split '/')[-1]) -Destination $OutFile }
    }

    AfterEach {
        $global:PROFILE = $script:SavedProfile
    }

    It 'updates the installed font and the profile' {
        $result = Invoke-Setup
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'OK'
        (Get-Step $result 'Profile').Status | Should -Be 'OK'
        $info = InModuleScope TerminalGlyphs -Parameters @{ Path = $script:Installed } { param($Path) Read-FontInfo -Path $Path }
        $info.Version | Should -Be ([version]'3.5.1')
        $info.FullName | Should -Be 'JetBrainsMonoNerdFontMono-Regular New'
        Join-Path $script:Fonts 'NerdFonts' 'JetBrainsMono' 'JetBrainsMonoNerdFont-Regular.ttf' | Should -Not -Exist
        [System.IO.File]::ReadAllText($script:ProfilePath) | Should -BeExactly "Import-Module TerminalGlyphs`n"
        Should -Invoke -ModuleName TerminalGlyphs Invoke-FontCacheRefresh -Times 1 -Exactly
    }

    It 'changes nothing with -WhatIf' {
        $before = Get-TreeSnapshot -Path $script:Case
        $result = Invoke-Setup @{ WhatIf = $true }
        (Get-Step $result 'Font JetBrainsMono').Status | Should -Be 'Skipped'
        (Get-Step $result 'Profile').Status | Should -Be 'Skipped'
        Get-TreeSnapshot -Path $script:Case | Should -Be $before
        Should -Invoke -ModuleName TerminalGlyphs Invoke-NerdFontDownload -Times 0
    }

    It 'is idempotent' {
        Invoke-Setup | Out-Null
        $second = Invoke-Setup
        (Get-Step $second 'Font JetBrainsMono').Status | Should -Be 'Unchanged'
        (Get-Step $second 'Profile').Status | Should -Be 'Unchanged'
    }
}
