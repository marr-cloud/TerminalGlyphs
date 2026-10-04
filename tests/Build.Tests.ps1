BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $buildScript = Join-Path $script:RepoRoot 'build.ps1'
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
        @{ File = 'TerminalGlyphs.data.json' }, @{ File = 'glyphs.json' }
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
}

Describe 'build validation' {
    It 'normalizes colors to upper-case hex without #' {
        $themes = New-ThemeFixture '{ "name": "default", "files": { "names": { "go.mod": "nf-dev-go" } } }' '{ "name": "default", "files": { "extensions": { ".go": "#00add8" } } }'
        $out = Join-Path $TestDrive 'ok'
        & $buildScript -ThemesPath $themes -OutputPath $out *> $null
        $built = Get-Content -LiteralPath (Join-Path $out 'TerminalGlyphs' '0.1.0' 'TerminalGlyphs.data.json') -Raw | ConvertFrom-Json -AsHashtable
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
