BeforeDiscovery {
    $upstream = Get-Module -ListAvailable -Name 'Terminal-Icons' | Where-Object Version -EQ '0.11.0' | Select-Object -First 1
    $canRun = $IsWindows -and $null -ne $upstream
}

Describe 'Terminal-Icons 0.11.0 (upstream) bug characterization' -Tag 'Upstream' -Skip:(-not $canRun) {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $appData = Join-Path $TestDrive 'appdata'
        [System.IO.Directory]::CreateDirectory($appData) | Out-Null
        $childEnv = @{ APPDATA = $appData }

        # The first import creates the theme XMLs inside the isolated APPDATA.
        $seed = Invoke-IsolatedPwsh -Environment $childEnv -Command 'Import-Module Terminal-Icons; "SEEDED"'
        $colorXml = Join-Path $appData 'powershell' 'Community' 'Terminal-Icons' 'devblackops_color.xml'

        # Emulate two sessions writing the same file at once: one <S N="Value"> line goes missing.
        $lines = [System.Collections.Generic.List[string]][System.IO.File]::ReadAllLines($colorXml)
        $valueIndex = $lines.FindIndex([Predicate[string]] { param($line) $line -match '<S N="Value">' })
        $lines.RemoveAt($valueIndex)
        [System.IO.File]::WriteAllLines($colorXml, $lines)
    }

    It 'seeds the theme XMLs on the first import' {
        $seed.Output | Should -Match 'SEEDED'
        $colorXml | Should -Exist
    }

    It 'fails to load inside try/catch (how Warp loads the profile) and leaves the XML corrupt' {
        $result = Invoke-IsolatedPwsh -Environment $childEnv -Command 'try { Import-Module Terminal-Icons } catch { "CAUGHT" }; "LOADED=" + [bool](Get-Module Terminal-Icons)'
        $result.Output | Should -Match 'LOADED=False'
        $result.All | Should -Match 'Import-Clixml'
        { Import-Clixml -LiteralPath $colorXml } | Should -Throw
    }

    It 'loads, and rewrites the XML, when imported outside try/catch' {
        $result = Invoke-IsolatedPwsh -Environment $childEnv -Command 'Import-Module Terminal-Icons; "LOADED=" + [bool](Get-Module Terminal-Icons)'
        $result.Output | Should -Match 'LOADED=True'
        { Import-Clixml -LiteralPath $colorXml } | Should -Not -Throw
    }
}
