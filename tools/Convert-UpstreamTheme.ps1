<#
.SYNOPSIS
    One-time migration of the Terminal-Icons themes (.psd1) to TerminalGlyphs themes (.jsonc).
.DESCRIPTION
    Kept in the repository to document where the built-in themes come from.
    Terminal-Icons is MIT licensed, Copyright (c) 2019 Brandon Olin.
    Glyphs that no longer exist in Nerd Fonts 3.5.1 are replaced, and extension keys without a
    leading dot (which never matched in Terminal-Icons) are moved to files.names.
.EXAMPLE
    ./tools/Convert-UpstreamTheme.ps1 -UpstreamDataPath ../Terminal-Icons/Terminal-Icons/Data -OutputPath ./themes
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UpstreamDataPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$header = @(
    '// Migrated from Terminal-Icons v0.11.0 (https://github.com/devblackops/Terminal-Icons).'
    '// Copyright (c) 2019 Brandon Olin. MIT License. See THIRD_PARTY_NOTICES.md.'
)
$terraformKeys = '.tf', '.tfvars', '.tf.json', '.tfvars.json', '.auto.tfvars', '.auto.tfvars.json'

function Get-RepairedGlyph {
    param([string]$Key, [string]$Glyph)
    switch ($Glyph) {
        'nf-dev-html5_multimedia' { return 'nf-md-folder_play' }
        'nf-dev-onedrive' { return 'nf-md-microsoft_onedrive' }
        'nf-dev-code_badge' {
            if ($Key -eq '.clixml') { return 'nf-md-xml' }
            if ($Key -in $terraformKeys) { return 'nf-dev-terraform' }
            throw "Unexpected use of nf-dev-code_badge for '$Key'."
        }
        default { return $Glyph }
    }
}

function Get-SortedMap {
    param([System.Collections.IDictionary]$Map)
    $sorted = [ordered]@{}
    foreach ($key in ($Map.Keys | Sort-Object { $_.ToLowerInvariant() }, { $_ })) { $sorted[$key] = $Map[$key] }
    $sorted
}

function ConvertFrom-UpstreamTheme {
    param([hashtable]$Upstream, [string]$Name, [string]$ThemeType)
    $result = [ordered]@{ name = $Name }
    foreach ($kinds in @(@('Files', 'files'), @('Directories', 'directories'))) {
        $source = $Upstream.Types[$kinds[0]]
        $names = [ordered]@{}
        $extensions = [ordered]@{}
        $links = [ordered]@{}
        $default = $null
        # Non-WellKnown keys first, so WellKnown wins if both define the same name.
        foreach ($key in @($source.Keys | Where-Object { $_ -cne 'WellKnown' })) {
            $value = $source[$key]
            if ($ThemeType -eq 'Icon') { $value = Get-RepairedGlyph -Key $key -Glyph $value }
            if ($key -ceq '') { $default = $value }
            elseif ($key -ceq 'symlink' -or $key -ceq 'junction') { $links[$key] = $value }
            elseif ($kinds[1] -eq 'files' -and $key.StartsWith('.')) { $extensions[$key] = $value }
            else { $names[$key] = $value }
        }
        foreach ($key in $source['WellKnown'].Keys) {
            $value = $source['WellKnown'][$key]
            if ($ThemeType -eq 'Icon') { $value = Get-RepairedGlyph -Key $key -Glyph $value }
            $names[$key] = $value
        }
        $section = [ordered]@{ names = (Get-SortedMap -Map $names) }
        if ($kinds[1] -eq 'files') { $section['extensions'] = (Get-SortedMap -Map $extensions) }
        $section['links'] = (Get-SortedMap -Map $links)
        if ($null -ne $default) { $section['default'] = $default }
        $result[$kinds[1]] = $section
    }
    $result
}

$sources = @(
    @{ File = 'iconThemes/devblackops.psd1'; Name = 'default'; Type = 'Icon'; Out = 'icons/default.jsonc' }
    @{ File = 'colorThemes/devblackops.psd1'; Name = 'default'; Type = 'Color'; Out = 'colors/default.jsonc' }
    @{ File = 'colorThemes/devblackops_light.psd1'; Name = 'light'; Type = 'Color'; Out = 'colors/light.jsonc' }
    @{ File = 'colorThemes/dracula.psd1'; Name = 'dracula'; Type = 'Color'; Out = 'colors/dracula.jsonc' }
)

$utf8 = [System.Text.UTF8Encoding]::new($false)
foreach ($source in $sources) {
    $upstream = Import-PowerShellDataFile -LiteralPath ([System.IO.Path]::Combine($UpstreamDataPath, $source.File))
    $theme = ConvertFrom-UpstreamTheme -Upstream $upstream -Name $source.Name -ThemeType $source.Type
    $target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($OutputPath, $source.Out))
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
    $json = $theme | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($target, ((@($header) + $json) -join "`n") + "`n", $utf8)
    "Wrote $target"
}
