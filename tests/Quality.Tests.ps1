BeforeDiscovery {
    $publicFunctions = @('Format-TerminalGlyph', 'Get-TerminalGlyph', 'Show-TerminalGlyphTheme', 'Find-NerdGlyph', 'Update-TerminalGlyphConfig', 'Install-TerminalGlyphSetup') |
        ForEach-Object { @{ Name = $_ } }
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $manifestPath = Get-BuiltManifestPath
    $module = Import-Module $manifestPath -Force -PassThru
}

AfterAll {
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'module manifest' {
    It 'targets pwsh 7.4+ Core only' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.PowerShellVersion | Should -Be ([version]'7.4')
        $manifest.CompatiblePSEditions | Should -Be @('Core')
        $manifest.Version | Should -Be ([version]'0.2.1')
        $manifest.Guid | Should -Be ([guid]'191db48e-7499-4eff-8584-fb8c62a2ddee')
    }

    It 'exports exactly the public API' {
        @($module.ExportedFunctions.Keys | Sort-Object) | Should -Be @('Find-NerdGlyph', 'Format-TerminalGlyph', 'Get-TerminalGlyph', 'Install-TerminalGlyphSetup', 'Show-TerminalGlyphTheme', 'Update-TerminalGlyphConfig')
        $module.ExportedCmdlets.Count | Should -Be 0
        $module.ExportedAliases.Count | Should -Be 0
    }
}

Describe '<Name> help' -ForEach $publicFunctions {
    BeforeAll { $help = Get-Help -Name $Name -Full }

    It 'has a synopsis' {
        $help.Synopsis | Should -Not -BeNullOrEmpty
        # Without comment-based help, Get-Help returns the syntax line ("Name [-Param] ...") as the synopsis.
        $help.Synopsis | Should -Not -Match ('^' + [regex]::Escape($Name) + '\s+\[')
    }

    It 'has at least one example' {
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
    }
}

Describe 'PSScriptAnalyzer' {
    It 'reports no errors or warnings in <Target>' -ForEach @(
        @{ Target = 'src' }, @{ Target = 'build.ps1' }, @{ Target = 'tools' }
    ) {
        Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0
        $results = Invoke-ScriptAnalyzer -Path (Join-Path $script:RepoRoot $Target) -Recurse -Settings (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1')
        $results | ForEach-Object { "$($_.ScriptName):$($_.Line) $($_.RuleName) $($_.Message)" } | Should -BeNullOrEmpty
    }

    It 'keeps source files ASCII-only' {
        $files = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src'), (Join-Path $script:RepoRoot 'tools') -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1', '*.ps1xml'
        $files += Get-Item -LiteralPath (Join-Path $script:RepoRoot 'build.ps1')
        $nonAscii = $files | Where-Object { [System.IO.File]::ReadAllText($_.FullName) -match '[^\x00-\x7F]' }
        $nonAscii.FullName | Should -BeNullOrEmpty
    }
}
