BeforeDiscovery {
    $userFonts = if ($IsWindows) { Join-Path $env:LOCALAPPDATA 'Microsoft' 'Windows' 'Fonts' } else { $null }
    $realFont = if ($userFonts -and (Test-Path -LiteralPath $userFonts)) {
        Get-ChildItem -LiteralPath $userFonts -Filter '*NerdFontMono-Regular.ttf' -ErrorAction Ignore | Select-Object -First 1
    }
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src' 'Private') -Filter '*.ps1')) { . $file.FullName }
}

Describe 'Read-FontInfo' {
    It 'reads the full name, the US English typographic family and the Nerd Fonts version' {
        $path = New-TestFont -Path (Join-Path $TestDrive 'a.ttf') -FullName 'JetBrainsMono NFM Regular' -Family 'JetBrainsMono NFM' -TypographicFamily 'JetBrainsMono Nerd Font Mono' -Version 'Version 2.304; ttfautohint (v1.8.4.7-5d5b);Nerd Fonts 3.5.1'
        $info = Read-FontInfo -Path $path
        $info.FullName | Should -BeExactly 'JetBrainsMono NFM Regular'
        $info.Family | Should -BeExactly 'JetBrainsMono Nerd Font Mono'
        $info.Version | Should -Be ([version]'3.5.1')
    }

    It 'falls back to the legacy family name' {
        $path = New-TestFont -Path (Join-Path $TestDrive 'b.ttf') -Family 'FiraCode Nerd Font Mono' -TypographicFamily ''
        (Read-FontInfo -Path $path).Family | Should -BeExactly 'FiraCode Nerd Font Mono'
    }

    It 'returns a null version for fonts that are not from Nerd Fonts' {
        $info = Read-FontInfo -Path (New-TestFont -Path (Join-Path $TestDrive 'c.ttf') -Version 'Version 1.0')
        $info.FullName | Should -Not -BeNullOrEmpty
        $info.Version | Should -BeNullOrEmpty
    }

    It 'returns $null for <Case>' -ForEach @(@{ Case = 'a truncated file'; Length = 20 }, @{ Case = 'an empty file'; Length = 0 }) {
        $bytes = [System.IO.File]::ReadAllBytes((New-TestFont -Path (Join-Path $TestDrive "full-$Length.ttf")))
        $path = Join-Path $TestDrive "cut-$Length.ttf"
        # 20 bytes keep the 12-byte header but cut the table directory.
        [System.IO.File]::WriteAllBytes($path, [byte[]]@($bytes | Select-Object -First $Length))
        Read-FontInfo -Path $path | Should -BeNullOrEmpty
    }

    It 'returns $null for a missing file' {
        Read-FontInfo -Path (Join-Path $TestDrive 'missing.ttf') | Should -BeNullOrEmpty
    }

    It 'reads an installed Nerd Font' -Skip:(-not $realFont) -ForEach @(@{ RealFont = $realFont }) {
        $info = Read-FontInfo -Path $RealFont.FullName
        $info.FullName | Should -Not -BeNullOrEmpty
        $info.Version | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-FontLocation' {
    It 'returns the per-user font folder of this platform' {
        $location = Get-FontLocation
        if ($IsWindows) {
            $location.Platform | Should -Be 'Windows'
            $location.Directory | Should -Be (Join-Path $env:LOCALAPPDATA 'Microsoft' 'Windows' 'Fonts')
        } elseif ($IsMacOS) {
            $location.Platform | Should -Be 'MacOS'
            $location.Directory | Should -Be (Join-Path $HOME 'Library' 'Fonts')
        } else {
            $location.Platform | Should -Be 'Linux'
        }
    }

    It 'honors XDG_DATA_HOME on Linux' -Skip:(-not $IsLinux) {
        $saved = $env:XDG_DATA_HOME
        try {
            $env:XDG_DATA_HOME = Join-Path $TestDrive 'xdg'
            (Get-FontLocation).Directory | Should -Be (Join-Path $TestDrive 'xdg' 'fonts')
        } finally {
            $env:XDG_DATA_HOME = $saved
        }
    }
}

Describe 'Get-NerdFontInstallation' {
    BeforeAll {
        $map = @{
            JetBrainsMono = 'JetBrainsMono'; FiraCode = 'FiraCode'; MesloLG = 'Meslo'; Hack = 'Hack'
            Iosevka = 'Iosevka'; IosevkaTerm = 'IosevkaTerm'; IosevkaTermSlab = 'IosevkaTermSlab'
        }
        $dir = Join-Path $TestDrive 'detect'
        New-TestFont -Path (Join-Path $dir 'JetBrainsMonoNerdFontMono-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'JetBrainsMonoNLNerdFont-Bold.ttf') -Version 'Version 2.304;Nerd Fonts 3.0.2' | Out-Null
        New-TestFont -Path (Join-Path $dir 'jetbrainsmononerdfont-italic.TTF') | Out-Null
        New-TestFont -Path (Join-Path $dir 'FiraCodeNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'MesloLGSDZNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'IosevkaTermSlabNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'NerdFonts' 'Hack' 'HackNerdFont-Regular.ttf') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'HackNerdFontMono-Regular.ttf'), 'not a font')
        New-TestFont -Path (Join-Path $dir 'FooBarNerdFont-Regular.ttf') | Out-Null
        New-TestFont -Path (Join-Path $dir 'Arial.ttf') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'FiraCodeNerdFont-Bold.ttf.20260101000000.old-nerdfont'), 'old')
        $families = @(Get-NerdFontInstallation -FontDirectory $dir -PackageMap $map -MinimumVersion '3.5.1')
        function Get-Family([string]$Name) { $families | Where-Object Name -EQ $Name }
    }

    It 'groups variants and other casings under one package and reports the oldest version' {
        $jetbrains = Get-Family 'JetBrainsMono'
        $jetbrains.Package | Should -Be 'JetBrainsMono'
        $jetbrains.Files.Count | Should -Be 3
        $jetbrains.Version | Should -Be ([version]'3.0.2')
        $jetbrains.IsOutdated | Should -BeTrue
    }

    It 'reports current families as not outdated' {
        (Get-Family 'FiraCode').IsOutdated | Should -BeFalse
        (Get-Family 'FiraCode').Files.Count | Should -Be 1
    }

    It 'uses the longest known prefix (<Name>)' -ForEach @(@{ Name = 'Meslo' }, @{ Name = 'IosevkaTermSlab' }) {
        (Get-Family $Name).Package | Should -Be $Name
    }

    It 'searches subfolders and treats unreadable files as outdated' {
        $hack = Get-Family 'Hack'
        $hack.Files.Count | Should -Be 2
        $hack.IsOutdated | Should -BeTrue
    }

    It 'reports unknown families without a package' {
        $unknown = Get-Family 'FooBar'
        $unknown.Package | Should -BeNullOrEmpty
        $unknown.Files.Count | Should -Be 1
    }

    It 'ignores fonts that are not Nerd Fonts and renamed leftovers' {
        $families.Files | Should -Not -Contain (Join-Path $dir 'Arial.ttf')
        @($families.Files | Where-Object { $_ -like '*.old-nerdfont' }).Count | Should -Be 0
        $families.Count | Should -Be 6
    }

    It 'returns nothing for a missing folder' {
        Get-NerdFontInstallation -FontDirectory (Join-Path $TestDrive 'nope') -PackageMap $map -MinimumVersion '3.5.1' | Should -BeNullOrEmpty
    }
}

Describe 'Save-NerdFontRelease' {
    BeforeAll {
        $script:Release = New-FakeNerdFontRelease -Root (Join-Path $TestDrive 'release') -Package 'JetBrainsMono' -FontName 'JetBrainsMonoNerdFontMono-Regular.ttf', 'JetBrainsMonoNerdFont-Bold.ttf'
        New-FakeNerdFontRelease -Root $script:Release -Package 'Hack' -FontName 'HackNerdFont-Regular.ttf' | Out-Null
    }

    BeforeEach {
        Mock Invoke-NerdFontDownload { Copy-Item -LiteralPath (Join-Path $script:Release ($Uri -split '/')[-1]) -Destination $OutFile }
        $work = Join-Path $TestDrive "work-$([guid]::NewGuid())"
        [System.IO.Directory]::CreateDirectory($work) | Out-Null
    }

    It 'returns the extracted fonts after checking the SHA-256' {
        $files = @(Save-NerdFontRelease -Package 'JetBrainsMono' -Version '3.5.1' -Destination $work)
        $files.Count | Should -Be 2
        [System.IO.Path]::GetFileName($files[0]) | Should -Be 'JetBrainsMonoNerdFont-Bold.ttf'
        $files | ForEach-Object { $_ | Should -Exist }
        (Read-FontInfo -Path $files[1]).FullName | Should -Be 'JetBrainsMonoNerdFontMono-Regular New'
        Should -Invoke Invoke-NerdFontDownload -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz' }
        Should -Invoke Invoke-NerdFontDownload -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/SHA-256.txt' }
    }

    It 'downloads SHA-256.txt once per destination' {
        Save-NerdFontRelease -Package 'JetBrainsMono' -Version '3.5.1' -Destination $work | Out-Null
        Save-NerdFontRelease -Package 'Hack' -Version '3.5.1' -Destination $work | Out-Null
        Should -Invoke Invoke-NerdFontDownload -Times 1 -Exactly -ParameterFilter { $Uri -like '*/SHA-256.txt' }
    }

    It 'refuses an archive whose checksum does not match' {
        Mock Invoke-NerdFontDownload {
            if ($Uri -like '*/SHA-256.txt') { Set-Content -LiteralPath $OutFile -Value "$('0' * 64)  JetBrainsMono.tar.xz" }
            else { Copy-Item -LiteralPath (Join-Path $script:Release 'JetBrainsMono.tar.xz') -Destination $OutFile }
        }
        { Save-NerdFontRelease -Package 'JetBrainsMono' -Version '3.5.1' -Destination $work } | Should -Throw '*Checksum mismatch*'
        Join-Path $work 'JetBrainsMono' | Should -Not -Exist
    }

    It 'fails when the package is not in SHA-256.txt' {
        { Save-NerdFontRelease -Package 'Nope' -Version '3.5.1' -Destination $work } | Should -Throw '*no entry for Nope.tar.xz*'
    }

    It 'lets download errors through' {
        Mock Invoke-NerdFontDownload { throw 'network down' }
        { Save-NerdFontRelease -Package 'Hack' -Version '3.5.1' -Destination $work } | Should -Throw '*network down*'
    }
}

Describe 'Invoke-FontCacheRefresh' {
    It 'returns whether fc-cache ran' {
        $expected = [bool](Get-Command -Name 'fc-cache' -CommandType Application -ErrorAction Ignore)
        Invoke-FontCacheRefresh -Directory $TestDrive | Should -Be $expected
    }
}

Describe 'Register-FontResource' -Skip:(-not $IsWindows) {
    It 'fails for a file Windows cannot load' {
        $path = Join-Path $TestDrive 'not-a-font.ttf'
        [System.IO.File]::WriteAllText($path, 'nope')
        { Register-FontResource -Path $path } | Should -Throw '*could not load*'
    }
}

Describe 'Install-NerdFontFile' {
    BeforeAll {
        $registryPath = 'HKCU:\Software\TerminalGlyphs.Tests\Fonts'
        function New-Case {
            $case = Join-Path $TestDrive "case-$([guid]::NewGuid())"
            $new = Join-Path $case 'new'
            [pscustomobject]@{
                Root   = $case
                Fonts  = Join-Path $case 'fonts'
                Source = @(
                    New-TestFont -Path (Join-Path $new 'TestNerdFontMono-Regular.ttf') -FullName 'Test NFM Regular'
                    New-TestFont -Path (Join-Path $new 'TestNerdFontMono-Bold.otf') -FullName 'Test NFM Bold'
                )
            }
        }
    }

    BeforeEach {
        Mock Register-FontResource { }
    }

    AfterAll {
        if ($IsWindows) { Remove-Item -LiteralPath 'HKCU:\Software\TerminalGlyphs.Tests' -Recurse -Force -ErrorAction Ignore }
    }

    It 'adds missing files on <Platform> without touching the registry' -ForEach @(@{ Platform = 'Linux' }, @{ Platform = 'MacOS' }) {
        $case = New-Case
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform $Platform
        $result.Added.Count | Should -Be 2
        Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf' | Should -Exist
        Should -Invoke Register-FontResource -Times 0
    }

    It 'registers added files for the current Windows user and loads them once' -Skip:(-not $IsWindows) {
        $case = New-Case
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform Windows -RegistryPath $registryPath
        $result.Added.Count | Should -Be 2
        $key = Get-Item -LiteralPath $registryPath
        $key.GetValue('Test NFM Regular (TrueType)') | Should -Be (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf')
        $key.GetValue('Test NFM Bold (OpenType)') | Should -Be (Join-Path $case.Fonts 'TestNerdFontMono-Bold.otf')
        Should -Invoke Register-FontResource -Times 1 -Exactly -ParameterFilter { $Path.Count -eq 2 }
    }

    It 'with -UpdateOnly, skips files that are not installed' {
        $case = New-Case
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform Windows -UpdateOnly -RegistryPath $registryPath
        $result.Added.Count + $result.Replaced | Should -Be 0
        $case.Fonts | Should -Not -Exist
    }

    It 'replaces installed files where they are, matching names without case' {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Root 'elsewhere' 'testnerdfontmono-regular.ttf') -FullName 'Old'
        $result = Install-NerdFontFile -SourceFile $case.Source -TargetDirectory $case.Fonts -Platform Linux -InstalledFile $installed -UpdateOnly
        $result.Replaced | Should -Be 1
        (Read-FontInfo -Path $installed).FullName | Should -Be 'Test NFM Regular'
        $case.Fonts | Should -Not -Exist
    }

    It 'on Windows, renames a file in use and copies the new one' {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf') -FullName 'Old'
        $script:CopyCalls = 0
        Mock Copy-Item {
            $script:CopyCalls++
            if ($script:CopyCalls -eq 1) { throw [System.IO.IOException]::new('The file is in use.') }
            [System.IO.File]::Copy($LiteralPath, $Destination, $true)
        }
        $result = Install-NerdFontFile -SourceFile $case.Source[0] -TargetDirectory $case.Fonts -Platform Windows -InstalledFile $installed -UpdateOnly
        $result.Renamed | Should -Be 1
        (Read-FontInfo -Path $installed).FullName | Should -Be 'Test NFM Regular'
        $stale = @(Get-ChildItem -LiteralPath $case.Fonts -Filter '*.old-nerdfont')
        $stale.Count | Should -Be 1
        $stale[0].Name | Should -Match '^TestNerdFontMono-Regular\.ttf\.\d{14}\.old-nerdfont$'
        (Read-FontInfo -Path $stale[0].FullName).FullName | Should -Be 'Old'
    }

    It 'on Windows, puts the original back when the new copy fails' {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf') -FullName 'Old'
        Mock Copy-Item { throw [System.IO.IOException]::new('The file is in use.') }
        $result = Install-NerdFontFile -SourceFile $case.Source[0] -TargetDirectory $case.Fonts -Platform Windows -InstalledFile $installed -UpdateOnly
        $result.Failed | Should -Be @('TestNerdFontMono-Regular.ttf')
        (Read-FontInfo -Path $installed).FullName | Should -Be 'Old'
        @(Get-ChildItem -LiteralPath $case.Fonts -Filter '*.old-nerdfont').Count | Should -Be 0
    }

    It 'on <Platform>, reports a failed copy without renaming' -ForEach @(@{ Platform = 'Linux' }, @{ Platform = 'MacOS' }) {
        $case = New-Case
        $installed = New-TestFont -Path (Join-Path $case.Fonts 'TestNerdFontMono-Regular.ttf') -FullName 'Old'
        Mock Copy-Item { throw [System.IO.IOException]::new('Permission denied.') }
        $result = Install-NerdFontFile -SourceFile $case.Source[0] -TargetDirectory $case.Fonts -Platform $Platform -InstalledFile $installed -UpdateOnly
        $result.Failed.Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $case.Fonts -Filter '*.old-nerdfont').Count | Should -Be 0
    }
}
