function Get-FullGlyphMap {
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param()

    if ($null -eq $script:FullGlyphs) {
        try {
            $script:FullGlyphs = Read-JsoncFile -Path $script:GlyphsPath
        } catch {
            Write-GlyphWarning -Message "could not load '$($script:GlyphsPath)': $($_.Exception.Message)"
            $script:FullGlyphs = @{}
        }
    }
    $script:FullGlyphs
}
