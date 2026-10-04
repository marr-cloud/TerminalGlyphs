BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    $configPath = Join-Path $TestDrive 'config.jsonc'
    $env:TERMINALGLYPHS_CONFIG = $configPath
    Import-Module (Get-BuiltManifestPath) -Force
    $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'go.mod', '[draft].md', 'robot.txt' -Directory '.claude'
    $schemaPath = Join-Path $script:RepoRoot 'schema' 'config.schema.json'
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Get-TerminalGlyph' {
    BeforeAll { Update-TerminalGlyphConfig }

    It 'explains which rule matched' {
        $info = Get-TerminalGlyph -Path (Join-Path $fixture 'go.mod')
        $info.PSObject.TypeNames[0] | Should -Be 'TerminalGlyphs.GlyphInfo'
        $info.Name | Should -Be 'go.mod'
        $info.IconName | Should -Be 'nf-dev-go'
        $info.Icon | Should -Be (Get-GlyphChar 'nf-dev-go')
        $info.Color | Should -Be '00ADD8'
        $info.Rule | Should -Be 'files.names[go.mod]'
        $info.Source | Should -Be 'theme:default'
    }

    It 'accepts Get-ChildItem output, including names with wildcard characters' {
        $infos = Get-ChildItem -LiteralPath $fixture -Force | Get-TerminalGlyph
        $infos.Name | Should -Contain '[draft].md'
        ($infos | Where-Object Name -EQ '.claude').IconName | Should -Be 'nf-cod-claude'
    }

    It 'accepts -LiteralPath' {
        (Get-TerminalGlyph -LiteralPath (Join-Path $fixture '[draft].md')).Rule | Should -Be 'files.extensions[.md]'
    }
}

Describe 'Update-TerminalGlyphConfig' {
    It 'reloads the config and shows warnings again' {
        [System.IO.File]::WriteAllText($configPath, '{ "icons": { "files": { "names": { "robot.txt": "nf-md-robot_angry", "x.txt": "nf-nope" } } } }')
        @(Update-TerminalGlyphConfig 3>&1).Count | Should -Be 1
        @(Update-TerminalGlyphConfig 3>&1).Count | Should -Be 1
        $info = Get-TerminalGlyph -Path (Join-Path $fixture 'robot.txt')
        $info.IconName | Should -Be 'nf-md-robot_angry'
        $info.Source | Should -Be 'user-config'
        [System.IO.File]::WriteAllText($configPath, '{ }')
        Update-TerminalGlyphConfig
        (Get-TerminalGlyph -Path (Join-Path $fixture 'robot.txt')).Source | Should -Be 'theme:default'
    }

    It 'supports -WhatIf' {
        { Update-TerminalGlyphConfig -WhatIf } | Should -Not -Throw
    }
}

Describe 'Find-NerdGlyph' {
    It 'finds glyphs by partial name' {
        $result = Find-NerdGlyph cloudflare
        $result.Name | Should -Contain 'nf-dev-cloudflare'
        ($result | Where-Object Name -EQ 'nf-dev-cloudflare').CodePoint | Should -Be 'U+E792'
    }

    It 'honors wildcards' {
        (Find-NerdGlyph 'nf-cod-claud?').Name | Should -Be 'nf-cod-claude'
    }

    It 'reports glyphs above U+FFFF' {
        (Find-NerdGlyph 'nf-md-arrow_right_thick' | Where-Object Name -EQ 'nf-md-arrow_right_thick').CodePoint | Should -Be 'U+F0055'
    }

    It 'returns nothing for unknown names' {
        Find-NerdGlyph 'zzz-no-such-glyph' | Should -BeNullOrEmpty
    }
}

Describe 'Show-TerminalGlyphTheme' {
    It 'lists one line per mapping' {
        Update-TerminalGlyphConfig
        $saved = $PSStyle.OutputRendering
        try {
            $PSStyle.OutputRendering = 'PlainText'
            $lines = Show-TerminalGlyphTheme -Kind files
        } finally {
            $PSStyle.OutputRendering = $saved
        }
        $lines | Should -Contain ('{0}  {1,-28} {2}' -f (Get-GlyphChar 'nf-dev-go'), 'go.mod', 'files.names')
        $lines | Should -Contain ('{0}  {1,-28} {2}' -f (Get-GlyphChar 'nf-dev-go'), '.go', 'files.extensions')
        ($lines | Where-Object { $_ -match 'directories\.' }) | Should -BeNullOrEmpty
    }
}

Describe 'config.schema.json' {
    It 'accepts a valid config' {
        $json = '{ "$schema": "x", "iconTheme": "default", "colorTheme": "dracula", "icons": { "files": { "names": { "justfile": "nf-md-format_list_checks" }, "extensions": { ".go": "nf-dev-go" }, "links": { "symlink": "nf-oct-file_symlink_file" }, "default": "nf-fa-file" }, "directories": { "names": { ".kiro": "nf-md-ghost" } } }, "colors": { "files": { "extensions": { ".go": "#00ADD8" } } } }'
        Test-Json -Json $json -SchemaFile $schemaPath | Should -BeTrue
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an unknown theme'; Json = '{ "colorTheme": "nope" }' }
        @{ Case = 'an extension without a dot'; Json = '{ "icons": { "files": { "extensions": { "go": "nf-dev-go" } } } }' }
        @{ Case = 'a value that is not a glyph name'; Json = '{ "icons": { "files": { "names": { "a": "go" } } } }' }
        @{ Case = 'an invalid color'; Json = '{ "colors": { "files": { "names": { "a": "blue" } } } }' }
        @{ Case = 'an unknown property'; Json = '{ "theme": "default" }' }
        @{ Case = 'extensions under directories'; Json = '{ "icons": { "directories": { "extensions": { ".x": "nf-dev-go" } } } }' }
    ) {
        Test-Json -Json $Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue | Should -BeFalse
    }

    It 'lists exactly the built-in themes' {
        $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json -AsHashtable
        $data = Get-Content -LiteralPath (Join-Path (Split-Path -Parent (Get-BuiltManifestPath)) 'TerminalGlyphs.data.json') -Raw | ConvertFrom-Json -AsHashtable
        @($schema['properties']['iconTheme']['enum'] | Sort-Object) | Should -Be @($data['iconThemes'].Keys | Sort-Object)
        @($schema['properties']['colorTheme']['enum'] | Sort-Object) | Should -Be @($data['colorThemes'].Keys | Sort-Object)
    }
}
