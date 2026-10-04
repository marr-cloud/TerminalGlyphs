function Save-NerdFontRelease {
    <#
    .SYNOPSIS
        Downloads a Nerd Fonts release package, checks its SHA-256 and extracts its font files.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Package,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$Destination,

        [string]$BaseUri = 'https://github.com/ryanoasis/nerd-fonts/releases/download'
    )

    $release = "$BaseUri/v$Version"
    $archiveName = "$Package.tar.xz"
    $sums = [System.IO.Path]::Combine($Destination, 'SHA-256.txt')
    if (-not [System.IO.File]::Exists($sums)) { Invoke-NerdFontDownload -Uri "$release/SHA-256.txt" -OutFile $sums }
    $expected = $null
    foreach ($line in [System.IO.File]::ReadAllLines($sums)) {
        if ($line -match '^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$' -and $Matches[2] -ceq $archiveName) {
            $expected = $Matches[1]
            break
        }
    }
    if (-not $expected) { throw "SHA-256.txt of Nerd Fonts $Version has no entry for $archiveName." }

    $archive = [System.IO.Path]::Combine($Destination, $archiveName)
    Invoke-NerdFontDownload -Uri "$release/$archiveName" -OutFile $archive
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw "Checksum mismatch for ${archiveName}: expected $expected, got $actual." }

    $extract = [System.IO.Path]::Combine($Destination, $Package)
    [System.IO.Directory]::CreateDirectory($extract) | Out-Null
    $tar = if ($IsWindows) { [System.IO.Path]::Combine($env:SystemRoot, 'System32', 'tar.exe') } else { 'tar' }
    & $tar -xf $archive -C $extract
    if ($LASTEXITCODE -ne 0) { throw "tar could not extract $archiveName (exit code $LASTEXITCODE)." }
    Get-ChildItem -LiteralPath $extract -Recurse -File |
        Where-Object { $_.Extension -in '.ttf', '.otf' } |
        Sort-Object -Property Name |
        ForEach-Object { $_.FullName }
}
