function Save-NerdFontRelease {
    <#
    .SYNOPSIS
        Downloads a Nerd Fonts release package, checks its SHA-256 and extracts its font files.
    .DESCRIPTION
        -ExpectedHash comes from the checksums shipped with the module (vendor/nerd-fonts/SHA-256.txt), so the
        archive is never checked against a file downloaded from the same server.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Package,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{64}$')]
        [string]$ExpectedHash,

        [Parameter(Mandatory)]
        [string]$Destination,

        [string]$BaseUri = 'https://github.com/ryanoasis/nerd-fonts/releases/download'
    )

    $archiveName = "$Package.tar.xz"
    $archive = [System.IO.Path]::Combine($Destination, $archiveName)
    Invoke-NerdFontDownload -Uri "$BaseUri/v$Version/$archiveName" -OutFile $archive
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedHash) { throw "Checksum mismatch for ${archiveName}: expected $ExpectedHash, got $actual." }

    $extract = [System.IO.Path]::Combine($Destination, $Package)
    [System.IO.Directory]::CreateDirectory($extract) | Out-Null
    $tar = if ($IsWindows) { [System.IO.Path]::Combine($env:SystemRoot, 'System32', 'tar.exe') } else { 'tar' }
    $tarOutput = (& $tar -xf $archive -C $extract 2>&1 | ForEach-Object { "$_" }) -join ' '
    if ($LASTEXITCODE -ne 0) {
        $hint = ''
        # GNU tar needs the xz program for .tar.xz files; the bsdtar shipped with Windows does not.
        if (-not $IsWindows -and -not (Get-Command -Name 'xz' -CommandType Application -ErrorAction Ignore)) { $hint = ' Install xz (xz-utils) and run again.' }
        throw "tar could not extract $archiveName (exit code $LASTEXITCODE): $tarOutput$hint"
    }
    Get-ChildItem -LiteralPath $extract -Recurse -File |
        Where-Object { $_.Extension -in '.ttf', '.otf' } |
        Sort-Object -Property Name |
        ForEach-Object { $_.FullName }
}
