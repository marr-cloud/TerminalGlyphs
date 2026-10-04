BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $script:RepoRoot 'src' 'Private' 'Read-JsoncFile.ps1')
    Import-Module (Join-Path $script:RepoRoot 'tools' 'DeviconsMapping.psm1') -Force
    function Get-Char([int]$Code) { [char]::ConvertFromUtf32($Code) }

    # A small fake world: reference data, glyph names and themes, all in TestDrive.
    function New-FakeWorld([string]$Name) {
        $root = Join-Path $TestDrive $Name
        $vendor = Join-Path $root 'vendor'
        $themes = Join-Path $root 'themes'
        foreach ($dir in $vendor, (Join-Path $themes 'icons'), (Join-Path $themes 'colors')) { [System.IO.Directory]::CreateDirectory($dir) | Out-Null }
        $entry = { param($Key, $Code, $Color, $Group) '  ["{0}"] = {{ icon = "{1}", color = "#{2}", cterm_color = "33", name = "{3}" }},' -f $Key, (Get-Char $Code), $Color, $Group }
        $names = @(
            'return {'
            & $entry '.prettierrc' 0xE600 '4285F4' 'PrettierConfig'
            & $entry '.prettierrc.json' 0xE600 '4285F4' 'PrettierConfig'
            & $entry 'go.mod' 0xE603 '00ADD8' 'GoMod'
            & $entry 'Dockerfile' 0xE601 '458EE6' 'Dockerfile'
            & $entry 'weird' 0xE6FF 'FFFFFF' 'Weird'
            '}'
        ) -join "`n"
        $extensions = @(
            'return {'
            & $entry 'env' 0xE602 'FAF743' 'Env'
            & $entry 'go' 0xE603 '00ADD8' 'Go'
            & $entry 'zig' 0xE604 'F69A1B' 'Zig'
            & $entry 'd.ts' 0xE605 'D59855' 'TypeScriptDeclaration'
            '}'
        ) -join "`n"
        [System.IO.File]::WriteAllText((Join-Path $vendor 'icons_by_filename.lua'), $names)
        [System.IO.File]::WriteAllText((Join-Path $vendor 'icons_by_file_extension.lua'), $extensions)
        $files = [ordered]@{}
        foreach ($file in 'icons_by_filename.lua', 'icons_by_file_extension.lua') { $files[$file] = (Get-FileHash -LiteralPath (Join-Path $vendor $file) -Algorithm SHA256).Hash }
        [System.IO.File]::WriteAllText((Join-Path $vendor 'manifest.json'), ([ordered]@{ commit = 'abc123'; files = $files } | ConvertTo-Json))

        $glyphs = [ordered]@{
            METADATA     = @{ version = '3.5.1' }
            'seti-zzz'   = @{ char = (Get-Char 0xE600); code = 'e600' }
            'dev-aaa'    = @{ char = (Get-Char 0xE600); code = 'e600' }
            'md-bbb'     = @{ char = (Get-Char 0xE601); code = 'e601' }
            'fa-ccc'     = @{ char = (Get-Char 0xE601); code = 'e601' }
            'fa-x'       = @{ char = (Get-Char 0xE602); code = 'e602' }
            'fa-xyz'     = @{ char = (Get-Char 0xE602); code = 'e602' }
            'dev-used'   = @{ char = (Get-Char 0xE603); code = 'e603' }
            'dev-a'      = @{ char = (Get-Char 0xE603); code = 'e603' }
            'weather-w'  = @{ char = (Get-Char 0xE604); code = 'e604' }
            'linux-l'    = @{ char = (Get-Char 0xE604); code = 'e604' }
            'seti-ts'    = @{ char = (Get-Char 0xE605); code = 'e605' }
        }
        $glyphNames = Join-Path $root 'glyphnames.json'
        [System.IO.File]::WriteAllText($glyphNames, ($glyphs | ConvertTo-Json))

        $header = "// Migrated from Terminal-Icons v0.11.0 (https://github.com/devblackops/Terminal-Icons).`n"
        [System.IO.File]::WriteAllText((Join-Path $themes 'icons' 'default.jsonc'), $header + '{ "name": "default", "files": { "names": { "go.mod": "nf-dev-used", "dockerfile": "nf-dev-aaa", "nocolor": "nf-dev-a" }, "extensions": { ".go": "nf-dev-used" } }, "directories": { "names": { ".git": "nf-dev-a" } } }' + "`n")
        foreach ($theme in 'default', 'light', 'dracula') {
            $dockerfile = if ($theme -eq 'light') { '' } else { '"dockerfile": "458EE6", ' }
            [System.IO.File]::WriteAllText((Join-Path $themes 'colors' "$theme.jsonc"), $header + "{ `"name`": `"$theme`", `"files`": { `"names`": { $dockerfile`"go.mod`": `"00ADD8`" }, `"extensions`": { `".go`": `"00ADD8`" } } }`n")
        }
        [pscustomobject]@{ Root = $root; Vendor = $vendor; Themes = $themes; GlyphNames = $glyphNames }
    }
}

AfterAll {
    Remove-Module DeviconsMapping -ErrorAction SilentlyContinue
}

Describe 'Confirm-DeviconsData' {
    It 'accepts the vendored reference and returns its commit' {
        Confirm-DeviconsData -VendorPath (Join-Path $script:RepoRoot 'vendor' 'nvim-web-devicons') | Should -Be '58447c1fca354bbf184425e4a8d01deecbd6f3c4'
    }

    It 'refuses data that does not match manifest.json' {
        $world = New-FakeWorld 'tampered'
        Add-Content -LiteralPath (Join-Path $world.Vendor 'icons_by_filename.lua') -Value '-- changed'
        { Confirm-DeviconsData -VendorPath $world.Vendor } | Should -Throw '*does not match manifest.json*'
    }
}

Describe 'Read-DeviconsFile' {
    BeforeAll { $world = New-FakeWorld 'read' }

    It 'reads names with their icon, upper-case color and group' {
        $entries = @(Read-DeviconsFile -Path (Join-Path $world.Vendor 'icons_by_filename.lua'))
        $entries.Count | Should -Be 5
        $prettier = $entries | Where-Object Key -EQ '.prettierrc'
        $prettier.Icon | Should -Be (Get-Char 0xE600)
        $prettier.Color | Should -BeExactly '4285F4'
        $prettier.Group | Should -Be 'PrettierConfig'
    }

    It 'adds the dot to extensions, including compound ones' {
        $keys = @(Read-DeviconsFile -Path (Join-Path $world.Vendor 'icons_by_file_extension.lua') -Extension).Key
        $keys | Should -Contain '.env'
        $keys | Should -Contain '.d.ts'
    }
}

Describe 'Select-GlyphName' {
    BeforeAll {
        $world = New-FakeWorld 'select'
        $index = Get-NerdGlyphIndex -GlyphNamesPath $world.GlyphNames
    }

    It 'picks <Expected> for U+<Code>' -ForEach @(
        @{ Code = 0xE600; Expected = 'nf-dev-aaa' }
        @{ Code = 0xE601; Expected = 'nf-md-bbb' }
        @{ Code = 0xE602; Expected = 'nf-fa-x' }
        @{ Code = 0xE604; Expected = 'nf-linux-l' }
    ) {
        Select-GlyphName -CodePoint $Code -GlyphIndex $index | Should -BeExactly $Expected
    }

    It 'prefers a name the theme already uses' {
        $used = [System.Collections.Generic.HashSet[string]]::new([string[]]@('nf-dev-used'))
        Select-GlyphName -CodePoint 0xE603 -GlyphIndex $index -UsedName $used | Should -BeExactly 'nf-dev-used'
    }

    It 'returns nothing for a code point without a name' {
        Select-GlyphName -CodePoint 0xE6FF -GlyphIndex $index | Should -BeNullOrEmpty
    }
}

Describe 'ConvertTo-LightColor' {
    It 'keeps <Hex>, which already has 3:1 contrast on white' -ForEach @(@{ Hex = '1354BF' }, @{ Hex = '123456' }) {
        ConvertTo-LightColor -Hex $Hex | Should -BeExactly $Hex
    }

    It 'darkens <Hex> to at least 3:1 on white, keeping its hue' -ForEach @(@{ Hex = 'FBF0DF' }, @{ Hex = 'F7DF1E' }, @{ Hex = '00ADD8' }, @{ Hex = 'FFFFFF' }) {
        $light = ConvertTo-LightColor -Hex $Hex
        Get-ContrastWithWhite -Hex $light | Should -BeGreaterOrEqual 3
        $light | Should -Match '^[0-9A-F]{6}$'
        if ((ConvertTo-Hsl -Hex $Hex)[1] -gt 0) {
            [Math]::Abs((ConvertTo-Hsl -Hex $light)[0] - (ConvertTo-Hsl -Hex $Hex)[0]) | Should -BeLessOrEqual 3
        }
    }

    It 'accepts a leading # and lower case' {
        ConvertTo-LightColor -Hex '#1354bf' | Should -BeExactly '1354BF'
    }

    It 'keeps <Hex>, an almost white color, almost grey when darkening it' -ForEach @(@{ Hex = 'FFF2F2' }, @{ Hex = 'FFF3D7' }, @{ Hex = 'FFFFCD' }) {
        $light = ConvertTo-LightColor -Hex $Hex
        Get-ContrastWithWhite -Hex $light | Should -BeGreaterOrEqual 3
        $channels = foreach ($offset in 0, 2, 4) { [Convert]::ToInt32($light.Substring($offset, 2), 16) }
        ($channels | Measure-Object -Maximum -Minimum | ForEach-Object { $_.Maximum - $_.Minimum }) | Should -BeLessOrEqual 51
    }
}

Describe 'ConvertTo-DraculaColor' {
    It 'maps <Hex> to <Expected>' -ForEach @(
        @{ Hex = 'E44D26'; Expected = 'FF5555' }
        @{ Hex = '3178C6'; Expected = '8BE9FD' }
        @{ Hex = '41B883'; Expected = '50FA7B' }
        @{ Hex = '#bd93f9'; Expected = 'BD93F9' }
        @{ Hex = '6D8086'; Expected = '6272A4' }
        @{ Hex = 'FFFFFF'; Expected = 'F8F8F2' }
        @{ Hex = '000000'; Expected = '6272A4' }
        @{ Hex = 'FFF2F2'; Expected = 'F8F8F2' }
        @{ Hex = 'FFF3D7'; Expected = 'F8F8F2' }
        @{ Hex = 'FFFFCD'; Expected = 'F8F8F2' }
        @{ Hex = 'FFAFAF'; Expected = 'FF5555' }
        @{ Hex = '839463'; Expected = 'F1FA8C' }
        @{ Hex = '77AA99'; Expected = '50FA7B' }
    ) {
        ConvertTo-DraculaColor -Hex $Hex | Should -BeExactly $Expected
    }
}

Describe 'Get-DeviconsComparison' {
    BeforeAll {
        $world = New-FakeWorld 'compare'
        $comparison = Get-DeviconsComparison -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames -ThemesPath $world.Themes
    }

    It 'returns the reference commit' {
        $comparison.Commit | Should -Be 'abc123'
    }

    It 'lists the entries the theme does not have' {
        @($comparison.New.Key | Sort-Object) | Should -Be @('.d.ts', '.env', '.prettierrc', '.prettierrc.json', '.zig')
        ($comparison.New | Where-Object Key -EQ '.zig').Glyph | Should -BeExactly 'nf-linux-l'
    }

    It 'treats a key that differs only in case as existing and reports the other glyph' {
        $docker = @($comparison.Different)
        $docker.Count | Should -Be 1
        $docker[0].Key | Should -BeExactly 'Dockerfile'
        $docker[0].CurrentKey | Should -BeExactly 'dockerfile'
        $docker[0].CurrentGlyph | Should -BeExactly 'nf-dev-aaa'
        $docker[0].Glyph | Should -BeExactly 'nf-md-bbb'
        $comparison.New.Key | Should -Not -Contain 'Dockerfile'
    }

    It 'leaves out entries whose glyph is the same code point, even under another name' {
        $comparison.New.Key + $comparison.Different.Key | Should -Not -Contain 'go.mod'
        $comparison.New.Key + $comparison.Different.Key | Should -Not -Contain '.go'
    }

    It 'lists glyphs that Nerd Fonts does not name' {
        @($comparison.Unmapped).Key | Should -Be @('weird')
    }

    It 'lists icons without a color and the reference color when there is one' {
        $nocolor = $comparison.MissingColor | Where-Object Key -EQ 'nocolor'
        @($nocolor.MissingIn) | Should -Be @('default', 'light', 'dracula')
        $nocolor.ReferenceColor | Should -BeNullOrEmpty
        $docker = $comparison.MissingColor | Where-Object Key -EQ 'dockerfile'
        @($docker.MissingIn) | Should -Be @('light')
        $docker.ReferenceColor | Should -BeExactly '458EE6'
    }

    It 'lists folders with an icon and without a color apart from files' {
        $folders = @($comparison.MissingFolderColor)
        $folders.Key | Should -Be @('.git')
        @($folders[0].MissingIn) | Should -Be @('default', 'light', 'dracula')
        $comparison.MissingColor.Key | Should -Not -Contain '.git'
    }
}

Describe 'Write-DeviconsReport' {
    It 'writes the groups, differences, unmapped glyphs and missing colors' {
        $world = New-FakeWorld 'report'
        $comparison = Get-DeviconsComparison -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames -ThemesPath $world.Themes
        $path = Join-Path $world.Root 'report.md'
        Write-DeviconsReport -Comparison $comparison -Path $path
        $text = [System.IO.File]::ReadAllText($path)
        $text | Should -Match '(?m)^### PrettierConfig$'
        $text | Should -Match ([regex]::Escape('| names | .prettierrc.json | nf-dev-aaa | 4285F4 |'))
        $text | Should -Match ([regex]::Escape('| names | Dockerfile | nf-dev-aaa | nf-md-bbb |'))
        $text | Should -Match 'weird'
        $text | Should -Match ([regex]::Escape('| names | nocolor | default, light, dracula |'))
        $text | Should -Match '(?m)^## Folders without a color'
        $text | Should -Match ([regex]::Escape('| .git | default, light, dracula |'))
        $text | Should -Match 'abc123'
    }
}

Describe 'Invoke-DeviconsApply' {
    BeforeAll {
        function Invoke-Apply($World, [string]$Decisions) {
            $path = Join-Path $World.Root "decisions-$([guid]::NewGuid()).jsonc"
            [System.IO.File]::WriteAllText($path, $Decisions)
            $comparison = Get-DeviconsComparison -VendorPath $World.Vendor -GlyphNamesPath $World.GlyphNames -ThemesPath $World.Themes
            Invoke-DeviconsApply -Comparison $comparison -ThemesPath $World.Themes -DecisionsPath $path
        }
        function Read-Theme($World, [string]$Relative) { Read-JsoncFile -Path (Join-Path $World.Themes $Relative) }
        $decisions = '{ "exclude": [ "group:Env", ".d.ts" ], "adopt": [ "dockerfile" ], "colors": { "nocolor": "#123456" } }'
    }

    It 'adds the new entries that are not excluded, with derived colors' {
        $world = New-FakeWorld 'apply-new'
        Invoke-Apply $world $decisions | Out-Null
        $icons = Read-Theme $world 'icons/default.jsonc'
        $icons['files']['names']['.prettierrc'] | Should -BeExactly 'nf-dev-aaa'
        $icons['files']['names']['.prettierrc.json'] | Should -BeExactly 'nf-dev-aaa'
        $icons['files']['extensions']['.zig'] | Should -BeExactly 'nf-linux-l'
        $icons['files']['extensions'].Keys | Should -Not -Contain '.env'
        $icons['files']['extensions'].Keys | Should -Not -Contain '.d.ts'
        (Read-Theme $world 'colors/default.jsonc')['files']['extensions']['.zig'] | Should -BeExactly 'F69A1B'
        (Read-Theme $world 'colors/light.jsonc')['files']['extensions']['.zig'] | Should -BeExactly (ConvertTo-LightColor -Hex 'F69A1B')
        (Read-Theme $world 'colors/dracula.jsonc')['files']['extensions']['.zig'] | Should -BeExactly (ConvertTo-DraculaColor -Hex 'F69A1B')
    }

    It 'changes an existing entry only when it is in adopt' {
        $world = New-FakeWorld 'apply-adopt'
        Invoke-Apply $world $decisions | Out-Null
        (Read-Theme $world 'icons/default.jsonc')['files']['names']['dockerfile'] | Should -BeExactly 'nf-md-bbb'
        (Read-Theme $world 'icons/default.jsonc')['files']['names']['go.mod'] | Should -BeExactly 'nf-dev-used'

        $other = New-FakeWorld 'apply-keep'
        Invoke-Apply $other '{ "exclude": [], "adopt": [], "colors": {} }' | Out-Null
        (Read-Theme $other 'icons/default.jsonc')['files']['names']['dockerfile'] | Should -BeExactly 'nf-dev-aaa'
        @((Read-Theme $other 'icons/default.jsonc')['files']['names'].Keys | Where-Object { $_ -eq 'dockerfile' }).Count | Should -Be 1
    }

    It 'fills missing colors from the reference or from the decisions file' {
        $world = New-FakeWorld 'apply-colors'
        Invoke-Apply $world $decisions | Out-Null
        (Read-Theme $world 'colors/default.jsonc')['files']['names']['nocolor'] | Should -BeExactly '123456'
        (Read-Theme $world 'colors/light.jsonc')['files']['names']['nocolor'] | Should -BeExactly '123456'
        (Read-Theme $world 'colors/dracula.jsonc')['files']['names']['nocolor'] | Should -BeExactly (ConvertTo-DraculaColor -Hex '123456')
        (Read-Theme $world 'colors/light.jsonc')['files']['names']['dockerfile'] | Should -BeExactly (ConvertTo-LightColor -Hex '458EE6')
    }

    It 'keeps the existing header and adds the credit line once' {
        $world = New-FakeWorld 'apply-header'
        Invoke-Apply $world $decisions | Out-Null
        $lines = [System.IO.File]::ReadAllLines((Join-Path $world.Themes 'icons' 'default.jsonc'))
        $lines[0] | Should -Match 'Migrated from Terminal-Icons'
        $lines[1] | Should -Match 'nvim-web-devicons'
        @($lines | Where-Object { $_ -match 'nvim-web-devicons' }).Count | Should -Be 1
    }

    It 'keeps an existing color of a new icon entry, whatever its case' {
        $world = New-FakeWorld 'apply-existing-color'
        & (Join-Path $script:RepoRoot 'tools' 'Set-ThemeEntry.ps1') -Path (Join-Path $world.Themes 'colors' 'default.jsonc') -Section files.names -Entries @{ '.PRETTIERRC' = 'ABCDEF' }
        Invoke-Apply $world $decisions | Out-Null
        $defaultNames = (Read-Theme $world 'colors/default.jsonc')['files']['names']
        @($defaultNames.Keys | Where-Object { $_ -eq '.prettierrc' }) | Should -BeExactly @('.PRETTIERRC')
        $defaultNames['.PRETTIERRC'] | Should -BeExactly 'ABCDEF'
        (Read-Theme $world 'colors/light.jsonc')['files']['names']['.prettierrc'] | Should -BeExactly (ConvertTo-LightColor -Hex '4285F4')
    }

    It 'changes nothing when run again' {
        $world = New-FakeWorld 'apply-twice'
        Invoke-Apply $world $decisions | Out-Null
        $before = Get-TreeSnapshot -Path $world.Themes
        $second = Invoke-Apply $world $decisions
        $second.Icons + $second.Colors | Should -Be 0
        Get-TreeSnapshot -Path $world.Themes | Should -Be $before
    }
}

Describe 'Import-DeviconsMapping.ps1' {
    BeforeAll { $script:Tool = Join-Path $script:RepoRoot 'tools' 'Import-DeviconsMapping.ps1' }

    It 'writes the report' {
        $world = New-FakeWorld 'tool-report'
        $report = Join-Path $world.Root 'out' 'report.md'
        & $script:Tool -Report $report -ThemesPath $world.Themes -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames 6> $null
        $report | Should -Exist
        [System.IO.File]::ReadAllText($report) | Should -Match '### PrettierConfig'
    }

    It 'applies a decisions file' {
        $world = New-FakeWorld 'tool-apply'
        $decisions = Join-Path $world.Root 'decisions.jsonc'
        [System.IO.File]::WriteAllText($decisions, '{ "exclude": [], "adopt": [], "colors": {} }')
        & $script:Tool -Apply -Decisions $decisions -ThemesPath $world.Themes -VendorPath $world.Vendor -GlyphNamesPath $world.GlyphNames 6> $null
        (Read-JsoncFile -Path (Join-Path $world.Themes 'icons' 'default.jsonc'))['files']['extensions']['.zig'] | Should -BeExactly 'nf-linux-l'
    }
}
