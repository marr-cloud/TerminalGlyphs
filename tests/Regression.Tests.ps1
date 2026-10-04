BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $manifestPath = Get-BuiltManifestPath
    $goGlyph = Get-GlyphChar 'nf-dev-go'
    $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'main.go', 'README.md' -Directory 'docs'
    $configDir = Join-Path $TestDrive 'config'
    [System.IO.Directory]::CreateDirectory($configDir) | Out-Null
    $validConfig = Join-Path $configDir 'valid.jsonc'
    [System.IO.File]::WriteAllText($validConfig, '{ "colorTheme": "default" }')
    $appData = Join-Path $TestDrive 'appdata'
    [System.IO.Directory]::CreateDirectory($appData) | Out-Null
}

Describe 'regression: Terminal-Icons import failures (spec section 2)' {
    It 'loads inside try/catch with ErrorActionPreference Stop even when the config is truncated' {
        $config = Join-Path $configDir 'truncated.jsonc'
        [System.IO.File]::WriteAllText($config, '{ "iconTheme": "default", "icons": { "files": ')
        $mainGo = Join-Path $fixture 'main.go'
        $command = @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module '$manifestPath'
    `$line = Get-Item -LiteralPath '$mainGo' | Format-TerminalGlyph
    "LOADED=`$([bool](Get-Module TerminalGlyphs))"
    "LINE=`$line"
} catch {
    "CAUGHT=`$(`$_.Exception.Message)"
}
"@
        $result = Invoke-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = $config; APPDATA = $appData }
        $plain = $result.All -replace "`e\[[0-9;]*m", ''
        $plain | Should -Match 'LOADED=True'
        $plain | Should -Not -Match 'CAUGHT='
        $plain | Should -Match 'could not read config'
        $plain | Should -Match ([regex]::Escape("LINE=$goGlyph  main.go"))
    }

    It 'never fails when many sessions import and list at the same time' {
        $failures = [System.Collections.Generic.List[string]]::new()
        foreach ($round in 1..3) {
            $barrier = [DateTime]::UtcNow.AddSeconds(5).Ticks
            $handles = foreach ($session in 1..8) {
                # Odd sessions start together; even sessions are staggered, like panes opening one after another.
                $delay = if ($session % 2) { 0 } else { Get-Random -Minimum 0 -Maximum 400 }
                $command = @"
while ([DateTime]::UtcNow.Ticks -lt $barrier) { }
Start-Sleep -Milliseconds $delay
try {
    Import-Module '$manifestPath'
    `$listing = Get-ChildItem -LiteralPath '$fixture' | Out-String -Width 200
    if (`$Error.Count -gt 0) { "FAIL: `$(`$Error -join ' | ')" }
    elseif (-not `$listing.Contains('$goGlyph')) { 'FAIL: no icon in listing' }
    else { 'OK' }
} catch {
    "FAIL: `$(`$_.Exception.Message)"
}
"@
                Start-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = $validConfig; APPDATA = $appData }
            }
            foreach ($result in ($handles | Wait-IsolatedPwsh)) {
                if ($result.Output -notmatch '(?m)^OK\s*$') { $failures.Add("round $($round): $($result.All.Trim())") }
            }
        }
        $failures | Should -BeNullOrEmpty
    }

    It 'does not write to the module folder, the config folder or APPDATA' {
        $before = Get-TreeSnapshot -Path (Split-Path -Parent $manifestPath), $configDir, $appData
        $command = "Import-Module '$manifestPath'; Get-ChildItem -LiteralPath '$fixture' | Out-String | Out-Null; 'DONE'"
        $result = Invoke-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = $validConfig; APPDATA = $appData }
        $result.Output | Should -Match 'DONE'
        Get-TreeSnapshot -Path (Split-Path -Parent $manifestPath), $configDir, $appData | Should -Be $before
        @(Get-ChildItem -LiteralPath $appData -Recurse -Force).Count | Should -Be 0
    }

    It 'warns when Terminal-Icons is also loaded' {
        $command = "New-Module -Name 'Terminal-Icons' -ScriptBlock { } | Import-Module; Import-Module '$manifestPath'; 'DONE'"
        $result = Invoke-IsolatedPwsh -Command $command -Environment @{ TERMINALGLYPHS_CONFIG = (Join-Path $configDir 'missing.jsonc') }
        $result.All | Should -Match 'Terminal-Icons is also loaded'
    }
}
