BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    function Get-RepoText([string]$Path) { [System.IO.File]::ReadAllText((Join-Path $script:RepoRoot $Path)) }
}

Describe 'licensing' {
    It 'LICENSE is MIT with both copyright lines' {
        $license = Get-RepoText 'LICENSE'
        $license | Should -Match 'MIT License'
        $license | Should -Match ([regex]::Escape('Copyright (c) 2026 marr-cloud'))
        $license | Should -Match ([regex]::Escape('Copyright (c) 2019 Brandon Olin'))
    }

    It 'THIRD_PARTY_NOTICES.md credits <Project>' -ForEach @(
        @{ Project = 'Terminal-Icons'; Copyright = 'Copyright (c) 2019 Brandon Olin' }
        @{ Project = 'DirColors'; Copyright = 'Copyright 2017 Dustin L. Howett' }
        @{ Project = 'Nerd Fonts'; Copyright = 'Copyright (c) 2014 Ryan L McIntyre' }
    ) {
        $notices = Get-RepoText 'THIRD_PARTY_NOTICES.md'
        $notices | Should -Match ([regex]::Escape($Project))
        $notices | Should -Match ([regex]::Escape($Copyright))
    }

    It 'ships LICENSE and THIRD_PARTY_NOTICES.md with the built module' {
        $moduleDir = Split-Path -Parent (Get-BuiltManifestPath)
        Join-Path $moduleDir 'LICENSE' | Should -Exist
        Join-Path $moduleDir 'THIRD_PARTY_NOTICES.md' | Should -Exist
    }
}

Describe 'documentation' {
    It 'README states the requirements and the migration from Terminal-Icons' {
        $readme = Get-RepoText 'README.md'
        $readme | Should -Match 'PowerShell 7\.4'
        $readme | Should -Match 'Nerd Font.*3\.5\.1'
        $readme | Should -Match 'Import-Module TerminalGlyphs'
        $readme | Should -Match 'TERMINALGLYPHS_CONFIG'
    }

    It 'CHANGELOG follows Keep a Changelog' {
        $changelog = Get-RepoText 'CHANGELOG.md'
        $changelog | Should -Match 'keepachangelog\.com'
        $changelog | Should -Match '## \[Unreleased\]'
    }

    It 'documents an install that can be repeated without nesting folders' {
        $readme = Get-RepoText 'README.md'
        $readme | Should -Match ([regex]::Escape('Copy-Item -Recurse -Force -Path ./out/TerminalGlyphs/* -Destination $target'))
        $modules = Join-Path $TestDrive 'Modules'
        $target = Join-Path $modules 'TerminalGlyphs'
        $source = Join-Path $script:RepoRoot 'out' 'TerminalGlyphs' '*'
        foreach ($attempt in 1..2) {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
            Copy-Item -Recurse -Force -Path $source -Destination $target
        }
        $manifests = @(Get-ChildItem -LiteralPath $modules -Recurse -Filter 'TerminalGlyphs.psd1')
        $manifests.Count | Should -Be 1
        $manifests[0].FullName | Should -Be (Join-Path $target '0.1.0' 'TerminalGlyphs.psd1')
    }
}

Describe 'workflows' {
    It 'CI runs on Windows and Linux' {
        $ci = Get-RepoText '.github/workflows/ci.yml'
        $ci | Should -Match 'windows-latest'
        $ci | Should -Match 'ubuntu-latest'
        $ci | Should -Match ([regex]::Escape('./build.ps1 -Task Test'))
    }

    It 'publishing only runs manually' {
        $publish = Get-RepoText '.github/workflows/publish.yml'
        $publish | Should -Match 'workflow_dispatch'
        $publish | Should -Not -Match '(?m)^\s*(push|pull_request|release|schedule):'
        $publish | Should -Match 'Publish-PSResource'
    }
}
