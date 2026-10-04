BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $script:RepoRoot 'src' 'Private' 'Update-ProfileImport.ps1')
    function New-Profile([string]$Content, [System.Text.Encoding]$Encoding = [System.Text.UTF8Encoding]::new($false)) {
        $path = Join-Path $TestDrive ([guid]::NewGuid()) 'profile.ps1'
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
        [System.IO.File]::WriteAllText($path, $Content, $Encoding)
        $path
    }
    function Get-Backup([string]$Path) { @(Get-ChildItem -LiteralPath (Split-Path -Parent $Path) -Filter '*.terminalglyphs-*.bak') }
}

Describe 'Update-ProfileImport' {
    It 'replaces the Terminal-Icons import and keeps a backup' {
        $original = "Invoke-Expression (&starship init powershell)`nImport-Module -Name Terminal-Icons`nfunction x { exit }`n"
        $path = New-Profile $original
        $result = Update-ProfileImport -Path $path
        $result.Status | Should -Be 'OK'
        $result.Path | Should -Be $path
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Invoke-Expression (&starship init powershell)`nImport-Module -Name TerminalGlyphs`nfunction x { exit }`n"
        $backup = Get-Backup $path
        $backup.Count | Should -Be 1
        $backup[0].Name | Should -Match '^profile\.ps1\.terminalglyphs-\d{14}\.bak$'
        [System.IO.File]::ReadAllText($backup[0].FullName) | Should -BeExactly $original
    }

    It 'changes only the module name in <Case>' -ForEach @(
        @{ Case = 'an indented line with quotes and parameters'; Line = "    Import-Module -Name 'Terminal-Icons' -ErrorAction SilentlyContinue"; Expected = "    Import-Module -Name 'TerminalGlyphs' -ErrorAction SilentlyContinue" }
        @{ Case = 'a positional name in double quotes'; Line = 'Import-Module "Terminal-Icons"'; Expected = 'Import-Module "TerminalGlyphs"' }
        @{ Case = 'another casing'; Line = 'import-module terminal-icons'; Expected = 'import-module TerminalGlyphs' }
    ) {
        $path = New-Profile "if (`$true) {`n$Line`n}`n"
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "if (`$true) {`n$Expected`n}`n"
    }

    It 'appends the import when there is none, ignoring comments and similar names' {
        $path = New-Profile "# Import-Module Terminal-Icons`nImport-Module Terminal-IconsExtra`n"
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "# Import-Module Terminal-Icons`nImport-Module Terminal-IconsExtra`n# Added by TerminalGlyphs`nImport-Module -Name TerminalGlyphs`n"
    }

    It 'adds a line break before appending to a file without a final newline' {
        $path = New-Profile 'Set-Alias ll ls'
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Set-Alias ll ls$([Environment]::NewLine)# Added by TerminalGlyphs$([Environment]::NewLine)Import-Module -Name TerminalGlyphs$([Environment]::NewLine)"
    }

    It 'is idempotent' {
        $path = New-Profile "Import-Module Terminal-Icons`n"
        Update-ProfileImport -Path $path | Out-Null
        $second = Update-ProfileImport -Path $path
        $second.Status | Should -Be 'Unchanged'
        (Get-Backup $path).Count | Should -Be 1
    }

    It 'asks to remove Terminal-Icons when both modules are imported' {
        $path = New-Profile "Import-Module TerminalGlyphs`nImport-Module Terminal-Icons`n"
        $result = Update-ProfileImport -Path $path
        $result.Status | Should -Be 'Unchanged'
        $result.Detail | Should -Match 'remove.*Terminal-Icons'
    }

    It 'creates the profile and its folder when they do not exist' {
        $path = Join-Path $TestDrive 'OneDrive' 'Documents' 'PowerShell' 'profile.ps1'
        $result = Update-ProfileImport -Path $path, (Join-Path $TestDrive 'other.ps1')
        $result.Status | Should -Be 'OK'
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "# Added by TerminalGlyphs$([Environment]::NewLine)Import-Module -Name TerminalGlyphs$([Environment]::NewLine)"
        [System.IO.File]::ReadAllBytes($path)[0] | Should -Not -Be 0xEF
        (Get-Backup $path).Count | Should -Be 0
    }

    It 'edits the first profile that already imports a module' {
        $first = New-Profile "Set-Alias ll ls`n"
        $second = New-Profile "Import-Module Terminal-Icons`n"
        $result = Update-ProfileImport -Path $first, $second
        $result.Path | Should -Be $second
        [System.IO.File]::ReadAllText($first) | Should -BeExactly "Set-Alias ll ls`n"
    }

    It 'keeps <Case>' -ForEach @(
        @{ Case = 'UTF-8 with BOM and CRLF'; Encoding = [System.Text.UTF8Encoding]::new($true); Newline = "`r`n"; Preamble = @(0xEF, 0xBB, 0xBF) }
        @{ Case = 'UTF-8 without BOM and LF'; Encoding = [System.Text.UTF8Encoding]::new($false); Newline = "`n"; Preamble = @() }
        @{ Case = 'UTF-16 LE with BOM'; Encoding = [System.Text.Encoding]::Unicode; Newline = "`r`n"; Preamble = @(0xFF, 0xFE) }
    ) {
        $path = New-Profile "Set-Alias ll ls$($Newline)Import-Module Terminal-Icons$Newline" $Encoding
        Update-ProfileImport -Path $path | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($path)
        if ($Preamble.Count -gt 0) { $bytes[0..($Preamble.Count - 1)] | Should -Be $Preamble }
        else { $bytes[0] | Should -Be ([byte][char]'S') }
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Set-Alias ll ls$($Newline)Import-Module TerminalGlyphs$Newline"
    }

    It 'keeps every byte of <Case> outside the module name' -ForEach @(
        @{ Case = 'an ANSI (cp1252) profile'; Text = [byte[]](0x23, 0x20) + [System.Text.Encoding]::ASCII.GetBytes('Configuraci') + [byte[]](0xF3, 0x6E, 0x20, 0x80, 0x0D, 0x0A) }
        @{ Case = 'a UTF-8 profile without BOM'; Text = [System.Text.UTF8Encoding]::new($false).GetBytes("# Funci$([char]0xF3)n $([char]0x20AC)`r`n") }
    ) {
        $ascii = [System.Text.Encoding]::ASCII
        $before = [byte[]]($Text + $ascii.GetBytes("Import-Module Terminal-Icons`r`n") + $Text)
        $expected = [byte[]]($Text + $ascii.GetBytes("Import-Module TerminalGlyphs`r`n") + $Text)
        $path = Join-Path $TestDrive ([guid]::NewGuid()) 'profile.ps1'
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
        [System.IO.File]::WriteAllBytes($path, $before)
        (Update-ProfileImport -Path $path).Status | Should -Be 'OK'
        [System.IO.File]::ReadAllBytes($path) | Should -Be $expected
    }

    It 'edits the target of a symbolic link and keeps the link' {
        $real = New-Profile "Import-Module Terminal-Icons`n"
        $link = Join-Path $TestDrive ([guid]::NewGuid()) 'profile.ps1'
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $link)) | Out-Null
        try {
            [System.IO.File]::CreateSymbolicLink($link, $real) | Out-Null
        } catch {
            Set-ItResult -Skipped -Because "this account cannot create symbolic links: $($_.Exception.Message)"
            return
        }
        $result = Update-ProfileImport -Path $link
        $result.Status | Should -Be 'OK'
        $result.Path | Should -Be $real
        (Get-Item -LiteralPath $link).LinkTarget | Should -Be $real
        [System.IO.File]::ReadAllText($real) | Should -BeExactly "Import-Module TerminalGlyphs`n"
        (Get-Backup $real).Count | Should -Be 1
        (Get-Backup $link).Count | Should -Be 0
    }

    It 'asks to remove a Terminal-Icons import it cannot replace (<Case>)' -ForEach @(
        @{ Case = 'several modules'; Content = "Set-Alias ll ls`nImport-Module posh-git, Terminal-Icons`n"; Line = 2 }
        @{ Case = 'a one-line block'; Content = "if (`$Host.Name -eq 'ConsoleHost') { Import-Module Terminal-Icons }`n"; Line = 1 }
    ) {
        $path = New-Profile $Content
        $result = Update-ProfileImport -Path $path
        $result.Status | Should -Be 'OK'
        $result.Detail | Should -BeLike "Add Import-Module TerminalGlyphs*; Terminal-Icons is still imported on line $Line, remove it"
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "$($Content)# Added by TerminalGlyphs`nImport-Module -Name TerminalGlyphs`n"
    }

    It 'does not ask to remove Terminal-Icons for comments and similar names' {
        $path = New-Profile "# Import-Module Terminal-Icons`nImport-Module Terminal-IconsExtra`nImport-Module Terminal-Icons`n"
        $result = Update-ProfileImport -Path $path
        $result.Detail | Should -Not -BeLike '*still imported*'
    }

    It 'appends with the newline style of the file' {
        $path = New-Profile "Set-Alias ll ls`r`n"
        Update-ProfileImport -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Set-Alias ll ls`r`n# Added by TerminalGlyphs`r`nImport-Module -Name TerminalGlyphs`r`n"
    }

    It 'changes nothing with -WhatIf' {
        $path = New-Profile "Import-Module Terminal-Icons`n"
        $result = Update-ProfileImport -Path $path -WhatIf
        $result.Status | Should -Be 'Skipped'
        [System.IO.File]::ReadAllText($path) | Should -BeExactly "Import-Module Terminal-Icons`n"
        (Get-Backup $path).Count | Should -Be 0
        @(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter '*.tmp').Count | Should -Be 0
    }
}
