BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-Module (Get-BuiltManifestPath) -Force
}

AfterAll {
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Merge-GlyphConfig' {
    It 'adds every section to the table with its source' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            $theme = [ordered]@{
                name        = 't'
                files       = [ordered]@{
                    names      = [ordered]@{ 'go.mod' = 'G' }
                    extensions = [ordered]@{ '.rs' = 'R' }
                    links      = [ordered]@{ symlink = 'S' }
                    default    = 'F'
                }
                directories = [ordered]@{ names = [ordered]@{ '.claude' = 'C' }; default = 'D' }
            }
            Merge-GlyphConfig -Table $table -Theme $theme -ThemeType Icon -Source 'theme:t' -Resolve { param($v) "<$v>" }

            $table.files.names['GO.MOD'].Value | Should -Be '<G>'
            $table.files.names['go.mod'].Name | Should -Be 'G'
            $table.files.names['go.mod'].Source | Should -Be 'theme:t'
            $table.files.extensions['.rs'].Value | Should -Be '<R>'
            $table.files.links['symlink'].Value | Should -Be '<S>'
            $table.files.default.Value | Should -Be '<F>'
            $table.directories.names['.claude'].Value | Should -Be '<C>'
            $table.directories.default.Value | Should -Be '<D>'
        }
    }

    It 'lets a later layer override an earlier one' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            Merge-GlyphConfig -Table $table -Theme ([ordered]@{ files = [ordered]@{ names = [ordered]@{ 'a' = 'theme' } } }) -ThemeType Icon -Source 'theme:t' -Resolve { param($v) $v }
            Merge-GlyphConfig -Table $table -Theme ([ordered]@{ files = [ordered]@{ names = [ordered]@{ 'A' = 'user' } } }) -ThemeType Icon -Source 'user-config' -Resolve { param($v) $v }
            $table.files.names['a'].Value | Should -Be 'user'
            $table.files.names['a'].Source | Should -Be 'user-config'
        }
    }

    It 'with -Validate, warns once per problem and skips invalid entries' {
        InModuleScope TerminalGlyphs {
            $script:Warned.Clear()
            $table = New-GlyphTable
            $layer = [ordered]@{ files = [ordered]@{ names = [ordered]@{ ok = 'nf-dev-go'; bad = 'nf-nope' } } }
            $parameters = @{
                Table = $table; Theme = $layer; ThemeType = 'Icon'; Source = 'user-config'; Origin = 'cfg.jsonc'; Validate = $true
                GlyphExists = { param($n) $n -eq 'nf-dev-go' }; Resolve = { param($v) $v }
            }
            $warnings = @(
                Merge-GlyphConfig @parameters 3>&1
                Merge-GlyphConfig @parameters 3>&1
            )
            $warnings.Count | Should -Be 1
            "$($warnings[0])" | Should -BeExactly "TerminalGlyphs: cfg.jsonc: ignoring unknown glyph 'nf-nope' at 'files.names[bad]'"
            $table.files.names.ContainsKey('bad') | Should -BeFalse
            $table.files.names['ok'].Value | Should -Be 'nf-dev-go'
        }
    }

    It 'ignores a null theme' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            { Merge-GlyphConfig -Table $table -Theme $null -ThemeType Icon -Source 's' -Resolve { param($v) $v } } | Should -Not -Throw
            $table.files.names.Count | Should -Be 0
        }
    }
}

Describe 'Resolve-TerminalGlyph' {
    BeforeAll {
        InModuleScope TerminalGlyphs {
            $icons = New-GlyphTable
            $colors = New-GlyphTable
            $iconTheme = [ordered]@{
                files       = [ordered]@{
                    names      = [ordered]@{ 'go.mod' = 'NAME-go.mod' }
                    extensions = [ordered]@{ '.ts' = 'EXT-.ts'; '.d.ts' = 'EXT-.d.ts'; '.gz' = 'EXT-.gz'; '.env' = 'EXT-.env' }
                    links      = [ordered]@{ symlink = 'LINK-file-symlink'; junction = 'LINK-file-junction' }
                    default    = 'DEFAULT-file'
                }
                directories = [ordered]@{
                    names   = [ordered]@{ '.claude' = 'NAME-.claude' }
                    links   = [ordered]@{ symlink = 'LINK-dir-symlink' }
                    default = 'DEFAULT-dir'
                }
            }
            $colorTheme = [ordered]@{ files = [ordered]@{ extensions = [ordered]@{ '.ts' = 'COLOR-.ts' } } }
            Merge-GlyphConfig -Table $icons -Theme $iconTheme -ThemeType Icon -Source 'theme:test' -Resolve { param($v) $v }
            Merge-GlyphConfig -Table $colors -Theme $colorTheme -ThemeType Color -Source 'theme:test' -Resolve { param($v) "ansi:$v" }
            $script:TGState = @{ Icons = $icons; Colors = $colors; Arrow = '->' }
        }
    }

    It '<Name> (directory: <Directory>, link: <LinkType>) -> <Expected> via <Rule>' -ForEach @(
        @{ Name = 'go.mod'; Directory = $false; LinkType = ''; Expected = 'NAME-go.mod'; Rule = 'files.names[go.mod]' }
        @{ Name = 'GO.MOD'; Directory = $false; LinkType = ''; Expected = 'NAME-go.mod'; Rule = 'files.names[GO.MOD]' }
        @{ Name = 'app.d.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.d.ts'; Rule = 'files.extensions[.d.ts]' }
        @{ Name = 'app.test.d.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.d.ts'; Rule = 'files.extensions[.d.ts]' }
        @{ Name = 'main.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.ts'; Rule = 'files.extensions[.ts]' }
        @{ Name = 'archive.tar.gz'; Directory = $false; LinkType = ''; Expected = 'EXT-.gz'; Rule = 'files.extensions[.gz]' }
        @{ Name = '.env'; Directory = $false; LinkType = ''; Expected = 'EXT-.env'; Rule = 'files.extensions[.env]' }
        @{ Name = 'README'; Directory = $false; LinkType = ''; Expected = 'DEFAULT-file'; Rule = 'files.default' }
        @{ Name = 'año.ts'; Directory = $false; LinkType = ''; Expected = 'EXT-.ts'; Rule = 'files.extensions[.ts]' }
        @{ Name = 'link.ts'; Directory = $false; LinkType = 'SymbolicLink'; Expected = 'LINK-file-symlink'; Rule = 'files.links[symlink]' }
        @{ Name = 'link.ts'; Directory = $false; LinkType = 'Junction'; Expected = 'LINK-file-junction'; Rule = 'files.links[junction]' }
        @{ Name = 'hard.ts'; Directory = $false; LinkType = 'HardLink'; Expected = 'EXT-.ts'; Rule = 'files.extensions[.ts]' }
        @{ Name = '.claude'; Directory = $true; LinkType = ''; Expected = 'NAME-.claude'; Rule = 'directories.names[.claude]' }
        @{ Name = 'src.ts'; Directory = $true; LinkType = ''; Expected = 'DEFAULT-dir'; Rule = 'directories.default' }
        @{ Name = 'linked'; Directory = $true; LinkType = 'SymbolicLink'; Expected = 'LINK-dir-symlink'; Rule = 'directories.links[symlink]' }
        @{ Name = 'jdir'; Directory = $true; LinkType = 'Junction'; Expected = 'DEFAULT-dir'; Rule = 'directories.default' }
    ) {
        $result = InModuleScope TerminalGlyphs -Parameters @{ N = $Name; D = $Directory; L = $LinkType } {
            param($N, $D, $L)
            Resolve-TerminalGlyph -Name $N -Directory:$D -LinkType $L
        }
        $result.IconName | Should -BeExactly $Expected
        $result.Icon | Should -BeExactly $Expected
        $result.Rule | Should -BeExactly $Rule
        $result.Source | Should -Be 'theme:test'
    }

    It 'resolves the color independently of the icon' {
        InModuleScope TerminalGlyphs {
            $ts = Resolve-TerminalGlyph -Name 'main.ts'
            $ts.ColorName | Should -Be 'COLOR-.ts'
            $ts.Color | Should -Be 'ansi:COLOR-.ts'
            (Resolve-TerminalGlyph -Name 'go.mod').Color | Should -BeNullOrEmpty
        }
    }
}
