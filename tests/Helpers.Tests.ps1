BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    foreach ($name in 'ConvertTo-AnsiSequence', 'Read-JsoncFile', 'Get-GlyphThemeEntry', 'Test-GlyphThemeEntry') {
        . (Join-Path $root 'src' 'Private' "$name.ps1")
    }
    function New-JsoncFile([string]$Content, [switch]$Bom) {
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).jsonc"
        [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new([bool]$Bom))
        $path
    }
}

Describe 'vendored Nerd Fonts data' {
    It 'is version 3.5.1 with 10995 glyphs' {
        $raw = Read-JsoncFile -Path (Join-Path $root 'vendor' 'nerd-fonts' 'glyphnames.json')
        $raw['METADATA']['version'] | Should -Be '3.5.1'
        ($raw.Keys | Where-Object { $_ -ne 'METADATA' }).Count | Should -Be 10995
    }
}

Describe 'ConvertTo-AnsiSequence' {
    It 'converts <Hex> to a 24-bit foreground sequence' -ForEach @(
        @{ Hex = '00ADD8'; Expected = "`e[38;2;0;173;216m" }
        @{ Hex = '#ffffff'; Expected = "`e[38;2;255;255;255m" }
    ) {
        ConvertTo-AnsiSequence -Hex $Hex | Should -BeExactly $Expected
    }

    It 'rejects <Hex>' -ForEach @(@{ Hex = 'GGGGGG' }, @{ Hex = 'FFF' }, @{ Hex = '' }) {
        { ConvertTo-AnsiSequence -Hex $Hex } | Should -Throw
    }
}

Describe 'Read-JsoncFile' {
    It 'parses comments and trailing commas' {
        $path = New-JsoncFile "// header`n{ `"a`": 1, /* inline */ `"b`": [1, 2,], }"
        $result = Read-JsoncFile -Path $path
        $result['a'] | Should -Be 1
        $result['b'].Count | Should -Be 2
    }

    It 'accepts a UTF-8 BOM' {
        (Read-JsoncFile -Path (New-JsoncFile '{ "a": 1 }' -Bom))['a'] | Should -Be 1
    }

    It 'keeps keys that differ only in case' {
        $result = Read-JsoncFile -Path (New-JsoncFile '{ "justfile": 1, "Justfile": 2 }')
        $result.Count | Should -Be 2
    }

    It 'throws "is empty" for <Case>' -ForEach @(@{ Case = 'an empty file'; Content = '' }, @{ Case = 'whitespace'; Content = "  `n " }) {
        { Read-JsoncFile -Path (New-JsoncFile $Content) } | Should -Throw '*is empty*'
    }

    It 'throws when the root is <Case>' -ForEach @(@{ Case = 'an array'; Content = '[1, 2]' }, @{ Case = 'a number'; Content = '42' }) {
        { Read-JsoncFile -Path (New-JsoncFile $Content) } | Should -Throw '*must contain a JSON object*'
    }

    It 'throws on truncated JSONC' {
        { Read-JsoncFile -Path (New-JsoncFile '{ "iconTheme": "default", "icons": { "files": ') } | Should -Throw
    }
}

Describe 'Get-GlyphThemeEntry' {
    It 'flattens names, extensions, links and default, skipping name and $schema' {
        $theme = [ordered]@{
            '$schema'   = 'x'
            name        = 'demo'
            files       = [ordered]@{
                names      = [ordered]@{ 'go.mod' = 'nf-dev-go' }
                extensions = [ordered]@{ '.rs' = 'nf-dev-rust' }
                links      = [ordered]@{ symlink = 'nf-oct-file_symlink_file' }
                default    = 'nf-fa-file'
            }
            directories = [ordered]@{ names = [ordered]@{ '.claude' = 'nf-cod-claude' } }
        }
        $entries = @(Get-GlyphThemeEntry -Theme $theme)
        $entries.Count | Should -Be 5
        ($entries | Where-Object Key -EQ 'go.mod').Section | Should -Be 'names'
        ($entries | Where-Object Section -EQ 'default').Key | Should -BeNullOrEmpty
        ($entries | Where-Object Section -EQ 'default').Value | Should -Be 'nf-fa-file'
        ($entries | Where-Object Key -EQ '.claude').Kind | Should -Be 'directories'
    }

    It 'reports a non-object section with a null key' {
        $entries = @(Get-GlyphThemeEntry -Theme ([ordered]@{ files = [ordered]@{ names = 'oops' } }))
        $entries[0].Section | Should -Be 'names'
        $entries[0].Key | Should -BeNullOrEmpty
    }
}

Describe 'Test-GlyphThemeEntry' {
    BeforeAll {
        $known = { param($name) $name -in 'nf-dev-go', 'nf-fa-file' }
        function New-Entry($Kind, $Section, $Key, $Value) {
            [pscustomobject]@{ Kind = $Kind; Section = $Section; Key = $Key; Value = $Value }
        }
    }

    It 'accepts a valid icon entry' {
        Test-GlyphThemeEntry -Entry (New-Entry 'files' 'names' 'go.mod' 'nf-dev-go') -ThemeType Icon -GlyphExists $known | Should -BeNullOrEmpty
    }

    It 'accepts the default icon' {
        Test-GlyphThemeEntry -Entry (New-Entry 'files' 'default' $null 'nf-fa-file') -ThemeType Icon -GlyphExists $known | Should -BeNullOrEmpty
    }

    It 'accepts color <Value>' -ForEach @(@{ Value = '00ADD8' }, @{ Value = '#00add8' }) {
        Test-GlyphThemeEntry -Entry (New-Entry 'files' 'extensions' '.go' $Value) -ThemeType Color | Should -BeNullOrEmpty
    }

    It 'reports: <Expected>' -ForEach @(
        @{ Kind = 'Files'; Section = 'names'; Key = 'a'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown section 'Files'" }
        @{ Kind = 'files'; Section = 'colors'; Key = 'a'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown section 'files.colors[a]'" }
        @{ Kind = 'directories'; Section = 'extensions'; Key = '.x'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown section 'directories.extensions[.x]'" }
        @{ Kind = 'files'; Section = 'links'; Key = 'hardlink'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "unknown link type at 'files.links[hardlink]'" }
        @{ Kind = 'files'; Section = 'extensions'; Key = 'rs'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "extension must start with '.' at 'files.extensions[rs]'" }
        @{ Kind = 'files'; Section = 'names'; Key = 'a'; Value = 'nf-nope'; Type = 'Icon'; Expected = "unknown glyph 'nf-nope' at 'files.names[a]'" }
        @{ Kind = 'files'; Section = 'names'; Key = 'a'; Value = 'blue'; Type = 'Color'; Expected = "invalid color 'blue' at 'files.names[a]'" }
        @{ Kind = 'files'; Section = 'names'; Key = $null; Value = 'oops'; Type = 'Icon'; Expected = "'files.names' must be an object" }
        @{ Kind = 'files'; Section = 'default'; Key = 'x'; Value = 'nf-dev-go'; Type = 'Icon'; Expected = "'files.default[x]' must be a string" }
        @{ Kind = 'files'; Section = $null; Key = $null; Value = 'oops'; Type = 'Icon'; Expected = "'files' must be an object" }
        @{ Kind = 'files'; Section = 'names'; Key = 'a'; Value = 42; Type = 'Icon'; Expected = "value at 'files.names[a]' must be a string" }
    ) {
        Test-GlyphThemeEntry -Entry (New-Entry $Kind $Section $Key $Value) -ThemeType $Type -GlyphExists $known | Should -BeExactly $Expected
    }
}
