BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedRendering = $PSStyle.OutputRendering
    # Redirected output (CI, piped runs) defaults to PlainText; the color assertions need ANSI.
    $PSStyle.OutputRendering = 'Ansi'
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
    Import-Module (Get-BuiltManifestPath) -Force
    InModuleScope TerminalGlyphs { Initialize-TerminalGlyph -Force }
    $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'main.go', 'año.go' -Directory 'docs'
    $goGlyph = Get-GlyphChar 'nf-dev-go'
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    $PSStyle.OutputRendering = $savedRendering
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Format-TerminalGlyph' {
    It 'prefixes the colored icon and resets the color' {
        $line = Get-Item -LiteralPath (Join-Path $fixture 'main.go') | Format-TerminalGlyph
        $line | Should -Match "^`e\[38;2;\d+;\d+;\d+m"
        $line | Should -BeLike "*$goGlyph  main.go*"
        # The reset sequence contains '[', a wildcard character for -BeLike.
        $line.EndsWith($PSStyle.Reset) | Should -BeTrue
    }

    It 'handles Unicode names' {
        Get-Item -LiteralPath (Join-Path $fixture 'año.go') | Format-TerminalGlyph | Should -BeLike "*$goGlyph  año.go*"
    }

    It 'formats directories' {
        Get-Item -LiteralPath (Join-Path $fixture 'docs') | Format-TerminalGlyph | Should -BeLike "*$(Get-GlyphChar 'nf-oct-repo')  docs*"
    }

    It 'omits ANSI sequences when OutputRendering is PlainText' {
        $saved = $PSStyle.OutputRendering
        try {
            $PSStyle.OutputRendering = 'PlainText'
            Get-Item -LiteralPath (Join-Path $fixture 'main.go') | Format-TerminalGlyph | Should -BeExactly "$goGlyph  main.go"
        } finally {
            $PSStyle.OutputRendering = $saved
        }
    }

    It 'shows the target of a junction' -Skip:(-not $IsWindows) {
        $link = Join-Path $TestDrive 'docs-link'
        New-Item -ItemType Junction -Path $link -Target (Join-Path $fixture 'docs') | Out-Null
        $line = Get-Item -LiteralPath $link | Format-TerminalGlyph
        $line | Should -BeLike "*docs-link $(Get-GlyphChar 'nf-md-arrow_right_thick') *docs*"
    }

    It 'returns the plain name when resolution fails' {
        Mock -ModuleName TerminalGlyphs Resolve-TerminalGlyph { throw 'boom' }
        Get-Item -LiteralPath (Join-Path $fixture 'main.go') | Format-TerminalGlyph | Should -BeExactly 'main.go'
    }

    It 'is used by Get-ChildItem' {
        Get-ChildItem -LiteralPath $fixture | Out-String | Should -BeLike "*$goGlyph  main.go*"
    }
}
