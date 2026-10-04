BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $savedConfig = $env:TERMINALGLYPHS_CONFIG
    $savedXdg = $env:XDG_CONFIG_HOME
    Import-Module (Get-BuiltManifestPath) -Force

    function Set-TestConfig([string]$Content, [switch]$Bom) {
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).jsonc"
        [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new([bool]$Bom))
        $env:TERMINALGLYPHS_CONFIG = $path
        $path
    }

    # Initializes from scratch and returns the warnings it emitted.
    function Initialize-ForTest {
        InModuleScope TerminalGlyphs { $script:Warned.Clear(); Initialize-TerminalGlyph -Force 3>&1 }
    }

    function Get-State { InModuleScope TerminalGlyphs { $script:TGState } }

    function Resolve-ForTest([string]$Name, [switch]$Directory) {
        InModuleScope TerminalGlyphs -Parameters @{ N = $Name; D = [bool]$Directory } { param($N, $D) Resolve-TerminalGlyph -Name $N -Directory:$D }
    }
}

AfterAll {
    $env:TERMINALGLYPHS_CONFIG = $savedConfig
    $env:XDG_CONFIG_HOME = $savedXdg
    Remove-Module TerminalGlyphs -ErrorAction SilentlyContinue
}

Describe 'Get-ConfigPath' {
    AfterEach {
        $env:TERMINALGLYPHS_CONFIG = $savedConfig
        $env:XDG_CONFIG_HOME = $savedXdg
    }

    It 'prefers TERMINALGLYPHS_CONFIG' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'explicit.jsonc'
        InModuleScope TerminalGlyphs { Get-ConfigPath } | Should -Be (Join-Path $TestDrive 'explicit.jsonc')
    }

    It 'falls back to XDG_CONFIG_HOME' {
        $env:TERMINALGLYPHS_CONFIG = $null
        $env:XDG_CONFIG_HOME = Join-Path $TestDrive 'xdg'
        InModuleScope TerminalGlyphs { Get-ConfigPath } | Should -Be (Join-Path $TestDrive 'xdg' 'terminalglyphs' 'config.jsonc')
    }

    It 'falls back to ~/.config' {
        $env:TERMINALGLYPHS_CONFIG = $null
        $env:XDG_CONFIG_HOME = $null
        $expected = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.config' 'terminalglyphs' 'config.jsonc'
        InModuleScope TerminalGlyphs { Get-ConfigPath } | Should -Be $expected
    }
}

Describe 'Initialize-TerminalGlyph' {
    It 'uses the built-in default themes without warnings when there is no config file' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        Initialize-ForTest | Should -BeNullOrEmpty
        $state = Get-State
        $state.IconTheme | Should -Be 'default'
        $state.ColorTheme | Should -Be 'default'
        $state.Icons.files.extensions.Count | Should -BeGreaterThan 200
        $state.Arrow | Should -Be (Get-GlyphChar 'nf-md-arrow_right_thick')
    }

    It 'loads the main.go icon from the built-in data' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        Initialize-ForTest | Out-Null
        $result = Resolve-ForTest 'main.go'
        $result.IconName | Should -Be 'nf-dev-go'
        $result.Icon | Should -Be (Get-GlyphChar 'nf-dev-go')
        $result.Color | Should -Match "^`e\[38;2;\d+;\d+;\d+m$"
        $result.Source | Should -Be 'theme:default'
    }

    It 'applies the theme choice and user overrides' {
        Set-TestConfig '{ "colorTheme": "dracula", "icons": { "files": { "names": { "justfile": "nf-md-format_list_checks" } } }, "colors": { "files": { "extensions": { ".go": "123456" } } } }' | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Get-State).ColorTheme | Should -Be 'dracula'
        $just = Resolve-ForTest 'JUSTFILE'
        $just.IconName | Should -Be 'nf-md-format_list_checks'
        $just.Source | Should -Be 'user-config'
        (Resolve-ForTest 'main.go').ColorName | Should -Be '123456'
        (Resolve-ForTest 'main.go').Color | Should -Be "`e[38;2;18;52;86m"
    }

    It 'resolves override glyphs that are not used by the built-in themes' {
        Set-TestConfig '{ "icons": { "files": { "names": { "robot.txt": "nf-md-robot_angry" } } } }' | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Resolve-ForTest 'robot.txt').Icon | Should -Be (Get-GlyphChar 'nf-md-robot_angry')
    }

    It 'accepts a theme name in another case' {
        Set-TestConfig '{ "colorTheme": "Dracula" }' | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Get-State).ColorTheme | Should -Be 'dracula'
    }

    It 'accepts a config saved with a UTF-8 BOM' {
        Set-TestConfig '{ "colorTheme": "light" }' -Bom | Out-Null
        Initialize-ForTest | Should -BeNullOrEmpty
        (Get-State).ColorTheme | Should -Be 'light'
    }

    It 'warns and uses the built-in theme when the config is <Case>' -ForEach @(
        @{ Case = 'truncated'; Content = '{ "iconTheme": "default", "icons": { "files": '; Expected = '*could not read config*' }
        @{ Case = 'empty'; Content = ''; Expected = '*is empty*' }
        @{ Case = 'an array'; Content = '[1]'; Expected = '*must contain a JSON object*' }
    ) {
        $path = Set-TestConfig $Content
        $warnings = @(Initialize-ForTest)
        $warnings.Count | Should -Be 1
        "$($warnings[0])" | Should -BeLike $Expected
        "$($warnings[0])" | Should -BeLike "*$path*"
        (Get-State).IconTheme | Should -Be 'default'
        (Resolve-ForTest 'main.go').IconName | Should -Be 'nf-dev-go'
    }

    It 'warns about an unknown theme and uses default' {
        Set-TestConfig '{ "colorTheme": "nope" }' | Out-Null
        $warnings = @(Initialize-ForTest)
        "$warnings" | Should -BeLike "*unknown colorTheme 'nope', using 'default'*"
        (Get-State).ColorTheme | Should -Be 'default'
    }

    It 'warns when icons is not an object' {
        Set-TestConfig '{ "icons": "nf-dev-go" }' | Out-Null
        "$(Initialize-ForTest)" | Should -BeLike "*'icons' must be an object*"
    }

    It 'skips only the invalid entries and warns once per session' {
        Set-TestConfig '{ "icons": { "files": { "names": { "ok.txt": "nf-dev-go", "bad.txt": "nf-nope" } } }, "colors": { "files": { "names": { "ok.txt": "blue" } } } }' | Out-Null
        $first = @(Initialize-ForTest)
        $first.Count | Should -Be 2
        $second = @(InModuleScope TerminalGlyphs { Initialize-TerminalGlyph -Force 3>&1 })
        $second.Count | Should -Be 0
        (Resolve-ForTest 'ok.txt').IconName | Should -Be 'nf-dev-go'
        (Resolve-ForTest 'bad.txt').Source | Should -Be 'theme:default'
    }

    It 'degrades to names without icons when the built-in data cannot be read' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        # $TestDrive is not visible inside the module scope, so pass the path in.
        $warnings = InModuleScope TerminalGlyphs -Parameters @{ Missing = (Join-Path $TestDrive 'nope.json') } {
            param($Missing)
            $saved = $script:DataPath
            $script:DataPath = $Missing
            try { $script:Warned.Clear(); Initialize-TerminalGlyph -Force 3>&1 } finally { $script:DataPath = $saved }
        }
        "$warnings" | Should -BeLike '*could not initialize*'
        (Resolve-ForTest 'main.go').Icon | Should -BeNullOrEmpty
    }

    It 'does nothing on a second call without -Force' {
        $env:TERMINALGLYPHS_CONFIG = Join-Path $TestDrive 'missing.jsonc'
        Initialize-ForTest | Out-Null
        InModuleScope TerminalGlyphs {
            $before = $script:TGState
            Initialize-TerminalGlyph
            [object]::ReferenceEquals($before, $script:TGState) | Should -BeTrue
        }
    }
}
