# Module body. build.ps1 prepends every function from src/Private and src/Public above this point.
# Importing must stay cheap and must never read data files or write anything to disk.
$script:DataPath = [System.IO.Path]::Combine($PSScriptRoot, 'TerminalGlyphs.data.json')
$script:GlyphsPath = [System.IO.Path]::Combine($PSScriptRoot, 'glyphs.json')
$script:TGState = $null
$script:FullGlyphs = $null
$script:Warned = [System.Collections.Generic.HashSet[string]]::new()

Update-FormatData -PrependPath ([System.IO.Path]::Combine($PSScriptRoot, 'TerminalGlyphs.format.ps1xml'))
