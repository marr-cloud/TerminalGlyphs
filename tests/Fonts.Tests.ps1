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
