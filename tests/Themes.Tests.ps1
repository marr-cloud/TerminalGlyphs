BeforeDiscovery {
    $root = Split-Path -Parent $PSScriptRoot
    $themeFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $root 'themes' 'icons') -Filter '*.jsonc' -ErrorAction SilentlyContinue |
            ForEach-Object { @{ Path = $_.FullName; Name = $_.BaseName; Type = 'Icon' } }
        Get-ChildItem -LiteralPath (Join-Path $root 'themes' 'colors') -Filter '*.jsonc' -ErrorAction SilentlyContinue |
            ForEach-Object { @{ Path = $_.FullName; Name = $_.BaseName; Type = 'Color' } }
    )
}

BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    foreach ($name in 'Read-JsoncFile', 'Get-GlyphThemeEntry', 'Test-GlyphThemeEntry') {
        . (Join-Path $root 'src' 'Private' "$name.ps1")
    }
    $script:nerd = Read-JsoncFile -Path (Join-Path $root 'vendor' 'nerd-fonts' 'glyphnames.json')
    $script:glyphExists = { param($name) $name -is [string] -and $name.StartsWith('nf-') -and $script:nerd.Contains($name.Substring(3)) }
}

Describe 'built-in themes' {
    It 'ships the default icon theme and the default, light and dracula color themes' {
        Join-Path $root 'themes' 'icons' 'default.jsonc' | Should -Exist
        foreach ($name in 'default', 'light', 'dracula') {
            Join-Path $root 'themes' 'colors' "$name.jsonc" | Should -Exist
        }
    }

    Context '<Name> (<Type>)' -ForEach $themeFiles {
        BeforeAll {
            $theme = Read-JsoncFile -Path $Path
            $entries = @(Get-GlyphThemeEntry -Theme $theme)
        }

        It 'declares a name equal to its file name' {
            $theme['name'] | Should -BeExactly $Name
        }

        It 'has only valid entries for Nerd Fonts 3.5.1' {
            $problems = foreach ($entry in $entries) {
                Test-GlyphThemeEntry -Entry $entry -ThemeType $Type -GlyphExists $script:glyphExists
            }
            $problems | Should -BeNullOrEmpty
        }

        It 'has no keys that differ only in case within a section' {
            $duplicates = $entries | Where-Object { $null -ne $_.Key } |
                Group-Object { "$($_.Kind).$($_.Section).$($_.Key.ToLowerInvariant())" } |
                Where-Object Count -GT 1
            $duplicates.Name | Should -BeNullOrEmpty
        }
    }

    Context 'migration from Terminal-Icons 0.11.0' {
        BeforeAll {
            $icons = Read-JsoncFile -Path (Join-Path $root 'themes' 'icons' 'default.jsonc')
            $colors = Read-JsoncFile -Path (Join-Path $root 'themes' 'colors' 'default.jsonc')
        }

        It 'repairs <Kind>.<Section>[<Key>] to <Glyph>' -ForEach @(
            @{ Kind = 'directories'; Section = 'names'; Key = 'media'; Glyph = 'nf-md-folder_play' }
            @{ Kind = 'directories'; Section = 'names'; Key = 'onedrive'; Glyph = 'nf-md-microsoft_onedrive' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.clixml'; Glyph = 'nf-md-xml' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tf'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tfvars'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tf.json'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.tfvars.json'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.auto.tfvars'; Glyph = 'nf-dev-terraform' }
            @{ Kind = 'files'; Section = 'extensions'; Key = '.auto.tfvars.json'; Glyph = 'nf-dev-terraform' }
        ) {
            $icons[$Kind][$Section][$Key] | Should -BeExactly $Glyph
        }

        It 'moves the dot-less "rakefile" extension to files.names' {
            $icons['files']['names']['rakefile'] | Should -BeExactly 'nf-oct-ruby'
            $icons['files']['extensions'].Contains('rakefile') | Should -BeFalse
        }

        It 'keeps every upstream mapping' {
            $icons['files']['extensions'].Count | Should -BeGreaterOrEqual 286
            $icons['files']['names'].Count | Should -BeGreaterOrEqual 75
            $icons['directories']['names'].Count | Should -BeGreaterOrEqual 45
            $colors['files']['extensions'].Count | Should -BeGreaterOrEqual 283
            $colors['directories']['names'].Count | Should -BeGreaterOrEqual 45
        }

        It 'keeps per-kind link icons' {
            $icons['files']['links']['symlink'] | Should -BeExactly 'nf-oct-file_symlink_file'
            $icons['directories']['links']['symlink'] | Should -BeExactly 'nf-cod-file_symlink_directory'
            $icons['files']['default'] | Should -BeExactly 'nf-fa-file'
            $icons['directories']['default'] | Should -BeExactly 'nf-oct-file_directory'
        }
    }
}
