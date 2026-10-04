function Initialize-TerminalGlyph {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if ($script:TGState -and -not $Force) { return }
    try {
        $data = Read-JsoncFile -Path $script:DataPath
        $builtinGlyphs = $data['glyphs']
        $configPath = Get-ConfigPath
        $config = Read-UserConfig -Path $configPath

        $requestedIcon = if ($config) { $config['iconTheme'] } else { $null }
        $requestedColor = if ($config) { $config['colorTheme'] } else { $null }
        $iconThemeName = Select-GlyphThemeName -Requested $requestedIcon -Available $data['iconThemes'] -Setting 'iconTheme' -ConfigPath $configPath
        $colorThemeName = Select-GlyphThemeName -Requested $requestedColor -Available $data['colorThemes'] -Setting 'colorTheme' -ConfigPath $configPath

        # These script blocks run inside Merge-GlyphConfig and see these variables through dynamic scoping.
        $glyphExists = { param($name) $name -is [string] -and ($builtinGlyphs.Contains($name) -or (Get-FullGlyphMap).Contains($name)) }
        $resolveIcon = {
            param($name)
            if ($builtinGlyphs.Contains($name)) { $builtinGlyphs[$name] } else { (Get-FullGlyphMap)[$name] }
        }
        $ansiCache = @{}
        $resolveColor = {
            param($hex)
            $key = $hex.TrimStart('#').ToUpperInvariant()
            if (-not $ansiCache.ContainsKey($key)) { $ansiCache[$key] = ConvertTo-AnsiSequence -Hex $key }
            $ansiCache[$key]
        }

        $icons = New-GlyphTable
        $colors = New-GlyphTable
        Merge-GlyphConfig -Table $icons -Theme $data['iconThemes'][$iconThemeName] -ThemeType Icon -Source "theme:$iconThemeName" -Resolve $resolveIcon
        Merge-GlyphConfig -Table $colors -Theme $data['colorThemes'][$colorThemeName] -ThemeType Color -Source "theme:$colorThemeName" -Resolve $resolveColor

        if ($config) {
            $layers = @(
                @{ Setting = 'icons'; Table = $icons; Type = 'Icon'; Resolve = $resolveIcon }
                @{ Setting = 'colors'; Table = $colors; Type = 'Color'; Resolve = $resolveColor }
            )
            foreach ($layer in $layers) {
                $section = $config[$layer.Setting]
                if ($null -eq $section) { continue }
                if ($section -isnot [System.Collections.IDictionary]) {
                    Write-GlyphWarning -Message "$($configPath): '$($layer.Setting)' must be an object, ignoring it."
                    continue
                }
                Merge-GlyphConfig -Table $layer.Table -Theme $section -ThemeType $layer.Type -Source 'user-config' -Origin $configPath -Validate -GlyphExists $glyphExists -Resolve $layer.Resolve
            }
        }

        $arrow = if ($builtinGlyphs.Contains('nf-md-arrow_right_thick')) { $builtinGlyphs['nf-md-arrow_right_thick'] } else { '->' }
        $script:TGState = @{
            Icons      = $icons
            Colors     = $colors
            Arrow      = $arrow
            IconTheme  = $iconThemeName
            ColorTheme = $colorThemeName
            ConfigPath = $configPath
        }
    } catch {
        Write-GlyphWarning -Message "could not initialize, showing names without icons: $($_.Exception.Message)"
        $script:TGState = @{
            Icons      = New-GlyphTable
            Colors     = New-GlyphTable
            Arrow      = '->'
            IconTheme  = $null
            ColorTheme = $null
            ConfigPath = $null
        }
    }
}
