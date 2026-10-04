@{
    RootModule           = 'TerminalGlyphs.psm1'
    ModuleVersion        = '0.3.3'
    CompatiblePSEditions = @('Core')
    GUID                 = '191db48e-7499-4eff-8584-fb8c62a2ddee'
    Author               = 'marr-cloud'
    CompanyName          = 'marr-cloud'
    Copyright            = '(c) 2026 marr-cloud. MIT License.'
    Description          = 'Nerd Font icons and colors for files and folders in Get-ChildItem. A reimplementation of Terminal-Icons that never writes to disk on import.'
    PowerShellVersion    = '7.4'
    FunctionsToExport    = @('Format-TerminalGlyph', 'Get-TerminalGlyph', 'Show-TerminalGlyphTheme', 'Find-NerdGlyph', 'Update-TerminalGlyphConfig', 'Install-TerminalGlyphSetup')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Terminal', 'Icons', 'NerdFonts', 'Glyphs', 'Color', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS')
            LicenseUri   = 'https://github.com/marr-cloud/TerminalGlyphs/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/marr-cloud/TerminalGlyphs'
            ReleaseNotes = 'https://github.com/marr-cloud/TerminalGlyphs/blob/main/CHANGELOG.md'
        }
    }
}
