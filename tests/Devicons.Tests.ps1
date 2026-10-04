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
    ) {
        ConvertTo-DraculaColor -Hex $Hex | Should -BeExactly $Expected
    }
}
