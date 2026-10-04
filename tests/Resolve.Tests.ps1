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

    It 'with -Validate, warns like an entry by entry check for <Case>' -ForEach @(
        @{ Case = 'kinds that are not objects'; Layer = [ordered]@{ files = 'nf-x'; foo = 'bar'; directories = $null } }
        @{ Case = 'a list as a kind'; Layer = [ordered]@{ files = @('nf-x') } }
        @{ Case = 'an unknown section and a default object'; Layer = [ordered]@{ files = [ordered]@{ nombres = [ordered]@{ a = 'nf-dev-go' }; default = [ordered]@{ a = 'nf-dev-go' } } } }
        @{ Case = 'a section that is not an object'; Layer = [ordered]@{ files = [ordered]@{ names = 'nf-dev-go' } } }
        @{ Case = 'invalid entries'; Layer = [ordered]@{ files = [ordered]@{ names = [ordered]@{ ok = 'nf-dev-go'; bad = 'nf-nope'; none = $null }; extensions = [ordered]@{ rs = 'nf-dev-go' }; links = [ordered]@{ weird = 'nf-dev-go' } } } }
    ) {
        InModuleScope TerminalGlyphs -Parameters @{ Layer = $Layer } {
            param($Layer)
            $glyphExists = { param($n) $n -eq 'nf-dev-go' }
            $expected = @(foreach ($entry in (Get-GlyphThemeEntry -Theme $Layer)) {
                    $problem = Test-GlyphThemeEntry -Entry $entry -ThemeType Icon -GlyphExists $glyphExists
                    if ($problem) { "TerminalGlyphs: cfg.jsonc: ignoring $problem" }
                })
            $expected.Count | Should -BeGreaterThan 0
            $script:Warned.Clear()
            $table = New-GlyphTable
            $warnings = @(Merge-GlyphConfig -Table $table -Theme $Layer -ThemeType Icon -Source 'user-config' -Origin 'cfg.jsonc' -Validate -GlyphExists $glyphExists -Resolve { param($v) $v } 3>&1)
            @($warnings | ForEach-Object { "$_" }) | Should -Be $expected
        }
    }

    It 'resolves each distinct value once' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            $theme = [ordered]@{
                files       = [ordered]@{ names = [ordered]@{ 'a' = 'X'; 'b' = 'X'; 'c' = 'Y' }; extensions = [ordered]@{ '.x' = 'X' }; default = 'Y' }
                directories = [ordered]@{ names = [ordered]@{ 'd' = 'X' } }
            }
            $calls = [System.Collections.Generic.List[string]]::new()
            Merge-GlyphConfig -Table $table -Theme $theme -ThemeType Icon -Source 's' -Resolve { param($v) $calls.Add($v); "<$v>" }
            @($calls | Sort-Object) | Should -Be @('X', 'Y')
            $table.files.names['b'].Value | Should -Be '<X>'
            $table.files.default.Value | Should -Be '<Y>'
            $table.directories.names['d'].Value | Should -Be '<X>'
        }
    }

    It 'takes values from -Lookup without calling -Resolve' {
        InModuleScope TerminalGlyphs {
            $table = New-GlyphTable
            $theme = [ordered]@{ files = [ordered]@{ names = [ordered]@{ 'a' = 'X'; 'b' = 'Y' }; default = 'X' } }
            $calls = [System.Collections.Generic.List[string]]::new()
            Merge-GlyphConfig -Table $table -Theme $theme -ThemeType Icon -Source 's' -Lookup @{ X = 'from-lookup' } -Resolve { param($v) $calls.Add($v); "<$v>" }
            @($calls) | Should -Be @('Y')
            $table.files.names['a'].Value | Should -Be 'from-lookup'
            $table.files.names['a'].Name | Should -Be 'X'
            $table.files.names['b'].Value | Should -Be '<Y>'
            $table.files.default.Value | Should -Be 'from-lookup'
        }
    }

    It 'builds the same tables as an entry by entry merge for the <Type> theme <Name>' -ForEach @(
        @{ Type = 'Icon'; Name = 'default' }
        @{ Type = 'Color'; Name = 'default' }
        @{ Type = 'Color'; Name = 'light' }
        @{ Type = 'Color'; Name = 'dracula' }
    ) {
        InModuleScope TerminalGlyphs -Parameters @{ Type = $Type; Name = $Name } {
            param($Type, $Name)
            $data = Read-JsoncFile -Path $script:DataPath
            $theme = if ($Type -eq 'Icon') { $data['iconThemes'][$Name] } else { $data['colorThemes'][$Name] }
            $glyphs = $data['glyphs']
            $resolve = if ($Type -eq 'Icon') { { param($v) $glyphs[$v] } } else { { param($v) ConvertTo-AnsiSequence -Hex $v } }

            # The merge as 0.3.0 did it: one entry object and one -Resolve call per entry.
            $expected = New-GlyphTable
            foreach ($entry in (Get-GlyphThemeEntry -Theme $theme)) {
                $target = $expected[$entry.Kind]
                if ($null -eq $target -or $null -eq $entry.Section) { continue }
                $resolved = & $resolve $entry.Value
                if ($null -eq $resolved) { continue }
                $valueName = $entry.Value
                if ($Type -eq 'Color' -and $valueName -is [string]) { $valueName = $valueName.TrimStart('#').ToUpperInvariant() }
                $item = [pscustomobject]@{ Value = $resolved; Name = $valueName; Source = 'theme' }
                if ($entry.Section -ceq 'default') { $target['default'] = $item }
                elseif ($null -ne $entry.Key -and $target.ContainsKey($entry.Section)) { $target[$entry.Section][$entry.Key] = $item }
            }

            $actual = New-GlyphTable
            Merge-GlyphConfig -Table $actual -Theme $theme -ThemeType $Type -Source 'theme' -Resolve $resolve
            $flatten = {
                param($Table)
                foreach ($kind in 'files', 'directories') {
                    foreach ($section in @($Table[$kind].Keys | Sort-Object)) {
                        $value = $Table[$kind][$section]
                        if ($value -is [hashtable]) {
                            foreach ($key in @($value.Keys | Sort-Object)) { '{0}.{1}[{2}]={3}|{4}|{5}' -f $kind, $section, $key, $value[$key].Value, $value[$key].Name, $value[$key].Source }
                        } elseif ($null -ne $value) {
                            '{0}.{1}={2}|{3}|{4}' -f $kind, $section, $value.Value, $value.Name, $value.Source
                        }
                    }
                }
            }
            $expectedLines = @(& $flatten $expected)
            $expectedLines.Count | Should -BeGreaterThan 50
            @(& $flatten $actual) | Should -Be $expectedLines

            # The way Initialize-TerminalGlyph merges the built-in themes: glyphs and ANSI sequences from data.json.
            $lookup = if ($Type -eq 'Icon') { $glyphs } else { $data['ansi'] }
            $withLookup = New-GlyphTable
            Merge-GlyphConfig -Table $withLookup -Theme $theme -ThemeType $Type -Source 'theme' -Lookup $lookup -Resolve { param($v) throw "unexpected -Resolve for $v" }
            @(& $flatten $withLookup) | Should -Be $expectedLines
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
