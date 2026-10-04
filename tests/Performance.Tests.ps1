Describe 'performance' -Tag 'Performance' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $manifestPath = Get-BuiltManifestPath
        $fixture = New-FileFixture -Root (Join-Path $TestDrive 'project') -File 'main.go', 'go.mod', 'README.md' -Directory '.claude'
        $childEnv = @{ TERMINALGLYPHS_CONFIG = (Join-Path $TestDrive 'missing.jsonc') }
    }

    It 'imports in under 100 ms (median of 5, pwsh -NoProfile)' {
        $times = foreach ($i in 1..5) {
            $result = Invoke-IsolatedPwsh -Environment $childEnv -Command "(Measure-Command { Import-Module '$manifestPath' }).TotalMilliseconds.ToString([cultureinfo]::InvariantCulture)"
            [double]::Parse($result.Output.Trim(), [cultureinfo]::InvariantCulture)
        }
        $median = ($times | Sort-Object)[2]
        Write-Host ("Import-Module: {0}  median {1:N1} ms" -f (($times | ForEach-Object { '{0:N1}' -f $_ }) -join ', '), $median)
        $median | Should -BeLessThan 100
    }

    It 'reports the first listing time' {
        $result = Invoke-IsolatedPwsh -Environment $childEnv -Command "Import-Module '$manifestPath'; (Measure-Command { Get-ChildItem -LiteralPath '$fixture' | Out-String }).TotalMilliseconds.ToString([cultureinfo]::InvariantCulture)"
        $firstListing = [double]::Parse($result.Output.Trim(), [cultureinfo]::InvariantCulture)
        Write-Host ("First Get-ChildItem (lazy initialization): {0:N1} ms" -f $firstListing)
        $firstListing | Should -BeLessThan 2000
    }
}
