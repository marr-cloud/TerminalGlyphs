function Install-NerdFontFile {
    <#
    .SYNOPSIS
        Copies Nerd Font files into the user's font folder, replacing the installed copies.
    .DESCRIPTION
        Each source file replaces the installed file with the same name (-InstalledFile), wherever it is. Files that
        are not installed are skipped with -UpdateOnly; otherwise they are copied to -TargetDirectory and, on Windows,
        registered for the current user and loaded. On Windows, an installed file that is in use is renamed to
        <name>.<yyyyMMddHHmmss>.old-nerdfont (UTC) before copying; Remove-StaleFontFile deletes it after a restart.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SourceFile,

        [Parameter(Mandatory)]
        [string]$TargetDirectory,

        [Parameter(Mandatory)]
        [ValidateSet('Windows', 'Linux', 'MacOS')]
        [string]$Platform,

        [string[]]$InstalledFile = @(),

        [switch]$UpdateOnly,

        [string]$RegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    )

    # This function runs only after Install-TerminalGlyphSetup approved the package, so the cmdlets below must not
    # ask again when the caller passes -Confirm or -WhatIf.
    $installed = @{}
    foreach ($path in $InstalledFile) { $installed[[System.IO.Path]::GetFileName($path)] = $path }
    $result = [pscustomobject]@{
        Added    = [System.Collections.Generic.List[string]]::new()
        Replaced = 0
        Renamed  = 0
        Failed   = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($source in $SourceFile) {
        $name = [System.IO.Path]::GetFileName($source)
        if ($installed.ContainsKey($name)) {
            $target = $installed[$name]
            try {
                Copy-Item -LiteralPath $source -Destination $target -Force -Confirm:$false -WhatIf:$false -ErrorAction Stop
                $result.Replaced++
                continue
            } catch {
                if ($Platform -ne 'Windows') {
                    $result.Failed.Add($name)
                    continue
                }
            }
            # Windows keeps fonts in use open: it allows renaming them but not overwriting them.
            $stale = '{0}.{1}.old-nerdfont' -f $target, [DateTime]::UtcNow.ToString('yyyyMMddHHmmss', [cultureinfo]::InvariantCulture)
            try {
                Move-Item -LiteralPath $target -Destination $stale -Confirm:$false -WhatIf:$false -ErrorAction Stop
            } catch {
                $result.Failed.Add($name)
                continue
            }
            try {
                Copy-Item -LiteralPath $source -Destination $target -Confirm:$false -WhatIf:$false -ErrorAction Stop
                $result.Renamed++
            } catch {
                $result.Failed.Add($name)
                try {
                    Move-Item -LiteralPath $stale -Destination $target -Force -Confirm:$false -WhatIf:$false -ErrorAction Stop
                } catch {
                    Write-Warning -Message "TerminalGlyphs: $name could not be restored now; it will be restored the next time you run Install-TerminalGlyphSetup."
                }
            }
            continue
        }
        if ($UpdateOnly) { continue }

        [System.IO.Directory]::CreateDirectory($TargetDirectory) | Out-Null
        $target = [System.IO.Path]::Combine($TargetDirectory, $name)
        try {
            Copy-Item -LiteralPath $source -Destination $target -Force -Confirm:$false -WhatIf:$false -ErrorAction Stop
        } catch {
            $result.Failed.Add($name)
            continue
        }
        if ($Platform -eq 'Windows') {
            $info = Read-FontInfo -Path $target
            $label = if ($info) { $info.FullName } else { [System.IO.Path]::GetFileNameWithoutExtension($target) }
            $kind = if ([System.IO.Path]::GetExtension($target) -eq '.otf') { 'OpenType' } else { 'TrueType' }
            if (-not (Test-Path -LiteralPath $RegistryPath)) { New-Item -Path $RegistryPath -Force -Confirm:$false -WhatIf:$false | Out-Null }
            New-ItemProperty -LiteralPath $RegistryPath -Name "$label ($kind)" -Value $target -PropertyType String -Force -Confirm:$false -WhatIf:$false | Out-Null
        }
        $result.Added.Add($target)
    }

    if ($Platform -eq 'Windows' -and $result.Added.Count -gt 0) { Register-FontResource -Path $result.Added.ToArray() }
    $result
}
