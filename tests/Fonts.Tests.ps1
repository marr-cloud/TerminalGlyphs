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
