BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $buildScript = Join-Path $script:RepoRoot 'build.ps1'
    $moduleVersion = (Import-PowerShellDataFile -Path (Join-Path $script:RepoRoot 'src' 'TerminalGlyphs.psd1')).ModuleVersion
    $manifestPath = Get-BuiltManifestPath
    $moduleDir = Split-Path -Parent $manifestPath
    $data = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.data.json') -Raw | ConvertFrom-Json -AsHashtable

    function New-ThemeFixture([string]$IconJson, [string]$ColorJson) {
        $dir = Join-Path $TestDrive ([guid]::NewGuid())
        [System.IO.Directory]::CreateDirectory((Join-Path $dir 'icons')) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $dir 'colors')) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'icons' 'default.jsonc'), $IconJson)
        [System.IO.File]::WriteAllText((Join-Path $dir 'colors' 'default.jsonc'), $ColorJson)
        $dir
    }
}

Describe 'build output' {
    It 'contains <File>' -ForEach @(
        @{ File = 'TerminalGlyphs.psd1' }, @{ File = 'TerminalGlyphs.psm1' }, @{ File = 'TerminalGlyphs.format.ps1xml' }
        @{ File = 'TerminalGlyphs.data.json' }, @{ File = 'glyphs.json' }, @{ File = 'nerdfonts.json' }
    ) {
        Join-Path $moduleDir $File | Should -Exist
    }

    It 'passes Test-ModuleManifest' {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'records Nerd Fonts 3.5.1' {
        $data['nerdFontsVersion'] | Should -Be '3.5.1'
    }

    It 'includes every glyph used by the icon themes plus the link arrow' {
        $json = $data['iconThemes'] | ConvertTo-Json -Depth 10 -Compress
        $used = [regex]::Matches($json, '"(nf-[a-z0-9_-]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $used.Count | Should -BeGreaterThan 100
        foreach ($name in $used) { $data['glyphs'].Contains($name) | Should -BeTrue -Because $name }
        $data['glyphs'].Contains('nf-md-arrow_right_thick') | Should -BeTrue
    }

    It 'includes the ANSI sequence of every color used by the color themes' {
        . (Join-Path $script:RepoRoot 'src' 'Private' 'Get-GlyphThemeEntry.ps1')
        $checked = 0
        foreach ($theme in $data['colorThemes'].Values) {
            foreach ($entry in (Get-GlyphThemeEntry -Theme $theme)) {
                $hex = $entry.Value.TrimStart('#')
                $expected = "$([char]27)[38;2;$([Convert]::ToInt32($hex.Substring(0, 2), 16));$([Convert]::ToInt32($hex.Substring(2, 2), 16));$([Convert]::ToInt32($hex.Substring(4, 2), 16))m"
                $data['ansi'][$hex.ToUpperInvariant()] | Should -BeExactly $expected -Because $entry.Value
                $checked++
            }
        }
        $checked | Should -BeGreaterThan 1000
    }

    It 'compiles every theme entry exactly as in themes/' {
        foreach ($helper in 'Read-JsoncFile', 'Get-GlyphThemeEntry') { . (Join-Path $script:RepoRoot 'src' 'Private' "$helper.ps1") }
        $checked = 0
        foreach ($type in @(@{ Dir = 'icons'; Key = 'iconThemes'; Color = $false }, @{ Dir = 'colors'; Key = 'colorThemes'; Color = $true })) {
            foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'themes' $type.Dir) -Filter '*.jsonc')) {
                $compiled = $data[$type.Key][$file.BaseName]
                $compiled | Should -Not -BeNullOrEmpty -Because $file.Name
                $source = @(Get-GlyphThemeEntry -Theme (Read-JsoncFile -Path $file.FullName))
                foreach ($entry in $source) {
                    $node = $compiled[$entry.Kind]
                    if ($null -ne $entry.Section) { $node = $node[$entry.Section] }
                    if ($null -ne $entry.Key) { $node = $node[$entry.Key] }
                    $expected = if ($type.Color) { $entry.Value.TrimStart('#').ToUpperInvariant() } else { $entry.Value }
                    $node | Should -BeExactly $expected -Because "$($file.Name) $($entry.Kind)/$($entry.Section)/$($entry.Key)"
                    $checked++
                }
                @(Get-GlyphThemeEntry -Theme $compiled).Count | Should -Be $source.Count -Because "$($file.Name) has no extra compiled entries"
            }
        }
        $checked | Should -BeGreaterThan 100
    }

    It 'stores glyphs above U+FFFF as surrogate pairs' {
        [char]::ConvertToUtf32($data['glyphs']['nf-md-arrow_right_thick'], 0) | Should -Be 0xF0055
    }

    It 'ships the full glyph map' {
        (Get-Content -LiteralPath (Join-Path $moduleDir 'glyphs.json') -Raw | ConvertFrom-Json -AsHashtable).Count | Should -Be 10995
    }

    It 'compiles every function from src into the psm1' {
        $psm1 = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.psm1') -Raw
        $files = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src' 'Private'), (Join-Path $script:RepoRoot 'src' 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
        foreach ($file in $files) { $psm1 | Should -Match ([regex]::Escape("function $($file.BaseName) {")) }
        $psm1 | Should -Match 'Update-FormatData'
    }

    It 'derives the Get-ChildItem view from Terminal-Icons' {
        $format = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.format.ps1xml') -Raw
        $format | Should -Not -Match 'Terminal-Icons\\Format-TerminalIcons'
        ([regex]::Matches($format, [regex]::Escape('TerminalGlyphs\Format-TerminalGlyph $_'))).Count | Should -Be 5
        ([regex]::Matches($format, [regex]::Escape('$_.LinkTarget'))).Count | Should -Be 2
        $format | Should -Match 'DirColors'
        { [xml]$format } | Should -Not -Throw
    }

    It 'imports in a clean session without errors' {
        $result = Invoke-IsolatedPwsh -Command "Import-Module '$manifestPath'; 'ERRORS=' + `$Error.Count"
        $result.Output | Should -Match 'ERRORS=0'
    }

    It 'maps Nerd Fonts file prefixes to release packages' {
        $fonts = Get-Content -LiteralPath (Join-Path $moduleDir 'nerdfonts.json') -Raw | ConvertFrom-Json -AsHashtable
        $fonts['version'] | Should -Be '3.5.1'
        $fonts['packages'].Count | Should -Be 72
        $fonts['packages']['JetBrainsMono'] | Should -BeExactly 'JetBrainsMono'
        $fonts['packages']['CaskaydiaCove'] | Should -BeExactly 'CascadiaCode'
        $fonts['packages']['MesloLG'] | Should -BeExactly 'Meslo'
        $fonts['packages']['InconsolataLGC'] | Should -BeExactly 'InconsolataLGC'
    }

    It 'stores the SHA-256 of every release package' {
        $fonts = Get-Content -LiteralPath (Join-Path $moduleDir 'nerdfonts.json') -Raw | ConvertFrom-Json -AsHashtable
        $fonts['archives'].Count | Should -Be 72
        $fonts['archives']['JetBrainsMono'] | Should -BeExactly '04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf'
        foreach ($package in ($fonts['packages'].Values | Sort-Object -Unique)) {
            $fonts['archives'][$package] | Should -Match '^[0-9a-f]{64}$' -Because $package
        }
    }

    It 'keeps the font index path in the module body without reading it on import' {
        $psm1 = Get-Content -LiteralPath (Join-Path $moduleDir 'TerminalGlyphs.psm1') -Raw
        $psm1 | Should -Match ([regex]::Escape("`$script:FontsPath = [System.IO.Path]::Combine(`$PSScriptRoot, 'nerdfonts.json')"))
    }
}

Describe 'build cleanup' {
    It 'removes module versions left by earlier builds' {
        $out = Join-Path $TestDrive 'stale-out'
        $stale = Join-Path $out 'TerminalGlyphs' '0.0.1'
        [System.IO.Directory]::CreateDirectory($stale) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $stale 'TerminalGlyphs.psd1'), '@{}')
        & $buildScript -OutputPath $out *> $null
        $stale | Should -Not -Exist
        Join-Path $out 'TerminalGlyphs' $moduleVersion 'TerminalGlyphs.psd1' | Should -Exist
    }

    It 'keeps folders that are not module versions' {
        $out = Join-Path $TestDrive 'mixed-out'
        $notes = Join-Path $out 'TerminalGlyphs' 'notes'
        [System.IO.Directory]::CreateDirectory($notes) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $notes 'keep.txt'), 'keep')
        & $buildScript -OutputPath $out *> $null
        Join-Path $notes 'keep.txt' | Should -Exist
    }

    It 'refuses an -OutputPath whose TerminalGlyphs folder is a source checkout' {
        $parent = Join-Path $TestDrive 'workspace'
        $checkout = Join-Path $parent 'TerminalGlyphs'
        [System.IO.Directory]::CreateDirectory((Join-Path $checkout 'src')) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $checkout 'build.ps1'), '# sources')
        [System.IO.File]::WriteAllText((Join-Path $checkout 'src' 'keep.ps1'), '# sources')
        { & $buildScript -OutputPath $parent *> $null } | Should -Throw '*source folder*'
        Join-Path $checkout 'build.ps1' | Should -Exist
        Join-Path $checkout 'src' 'keep.ps1' | Should -Exist
    }
}

Describe 'build validation' {
    It 'normalizes colors to upper-case hex without #' {
        $themes = New-ThemeFixture '{ "name": "default", "files": { "names": { "go.mod": "nf-dev-go" } } }' '{ "name": "default", "files": { "extensions": { ".go": "#00add8" } } }'
        $out = Join-Path $TestDrive 'ok'
        & $buildScript -ThemesPath $themes -OutputPath $out *> $null
        $built = Get-Content -LiteralPath (Join-Path $out 'TerminalGlyphs' $moduleVersion 'TerminalGlyphs.data.json') -Raw | ConvertFrom-Json -AsHashtable
        $built['colorThemes']['default']['files']['extensions']['.go'] | Should -BeExactly '00ADD8'
    }

    It 'fails on <Case>' -ForEach @(
        @{ Case = 'an unknown glyph'; Icons = '{ "name": "default", "files": { "names": { "go.mod": "nf-dev-nope" } } }'; Colors = '{ "name": "default" }'; Expected = "unknown glyph 'nf-dev-nope'" }
        @{ Case = 'an invalid color'; Icons = '{ "name": "default" }'; Colors = '{ "name": "default", "files": { "names": { "a": "blue" } } }'; Expected = "invalid color 'blue'" }
        @{ Case = 'keys that differ only in case'; Icons = '{ "name": "default", "files": { "names": { "justfile": "nf-dev-go", "Justfile": "nf-dev-go" } } }'; Colors = '{ "name": "default" }'; Expected = "duplicate key 'Justfile'" }
        @{ Case = 'a name that does not match the file'; Icons = '{ "name": "other" }'; Colors = '{ "name": "default" }'; Expected = "'name' must be 'default'" }
        @{ Case = 'malformed JSONC'; Icons = '{ "name": "default",'; Colors = '{ "name": "default" }'; Expected = 'default.jsonc' }
    ) {
        $themes = New-ThemeFixture $Icons $Colors
        { & $buildScript -ThemesPath $themes -OutputPath (Join-Path $TestDrive 'bad') *> $null } | Should -Throw "*$Expected*"
    }
}

Describe 'vendored data checks' {
    BeforeAll {
        function Copy-Vendor([string]$Name) {
            $vendor = Join-Path $TestDrive $Name
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'vendor' 'nerd-fonts') -Destination $vendor -Recurse
            $vendor
        }
    }

    It 'fails when a vendored file does not match manifest.json' {
        $vendor = Copy-Vendor 'vendor-tampered'
        Add-Content -LiteralPath (Join-Path $vendor 'SHA-256.txt') -Value "$('0' * 64)  Extra.tar.xz"
        { & $buildScript -VendorPath $vendor -OutputPath (Join-Path $TestDrive 'tampered-out') *> $null } | Should -Throw '*SHA-256.txt*manifest.json*'
    }

    It 'fails when manifest.json names another Nerd Fonts version than glyphnames.json' {
        $vendor = Copy-Vendor 'vendor-version'
        $manifest = Join-Path $vendor 'manifest.json'
        [System.IO.File]::WriteAllText($manifest, [System.IO.File]::ReadAllText($manifest).Replace('"3.5.1"', '"3.6.0"'))
        { & $buildScript -VendorPath $vendor -OutputPath (Join-Path $TestDrive 'version-out') *> $null } | Should -Throw '*3.6.0*3.5.1*'
    }
}

Describe 'vendored data checks with an incomplete manifest' {
    BeforeAll {
        function Copy-Vendor([string]$Name) {
            $vendor = Join-Path $TestDrive $Name
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'vendor' 'nerd-fonts') -Destination $vendor -Recurse
            $vendor
        }
    }

    It 'fails when manifest.json does not list a file the build reads' {
        $vendor = Copy-Vendor 'vendor-unlisted'
        $manifest = Join-Path $vendor 'manifest.json'
        $json = [System.IO.File]::ReadAllText($manifest) -replace '(?m)^\s*"fonts\.json": "[0-9A-F]{64}",\r?\n', ''
        [System.IO.File]::WriteAllText($manifest, $json)
        { & $buildScript -VendorPath $vendor -OutputPath (Join-Path $TestDrive 'unlisted-out') *> $null } | Should -Throw '*manifest.json does not list fonts.json*'
    }

    It 'names the missing file when a listed file does not exist' {
        $vendor = Copy-Vendor 'vendor-missing'
        Remove-Item -LiteralPath (Join-Path $vendor 'fonts.json')
        { & $buildScript -VendorPath $vendor -OutputPath (Join-Path $TestDrive 'missing-out') *> $null } | Should -Throw '*fonts.json is listed in manifest.json but missing*'
    }
}
