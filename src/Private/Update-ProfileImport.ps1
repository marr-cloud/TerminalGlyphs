function Update-ProfileImport {
    <#
    .SYNOPSIS
        Makes a PowerShell profile import TerminalGlyphs instead of Terminal-Icons.
    .DESCRIPTION
        Edits the first profile in -Path that already imports Terminal-Icons or TerminalGlyphs, or else the first
        profile in -Path. Keeps a backup, the file encoding and the line endings, and writes atomically.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$Path = @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts, $PROFILE.AllUsersCurrentHost, $PROFILE.AllUsersAllHosts)
    )

    $oldImport = '(?im)^(?<lead>[ \t]*Import-Module[ \t]+(?:-Name[ \t]+)?)(?<quote>[''"]?)Terminal-Icons\k<quote>(?=[ \t;]|\r?$)'
    $newImport = '(?im)^[ \t]*Import-Module[ \t]+(?:-Name[ \t]+)?[''"]?TerminalGlyphs(?=[''" \t;]|\r?$)'
    $candidates = @($Path | Where-Object { $_ })
    if ($candidates.Count -eq 0) { throw 'This PowerShell host has no profile path.' }

    $target = $candidates[0]
    foreach ($candidate in $candidates) {
        if (-not [System.IO.File]::Exists($candidate)) { continue }
        $content = [System.IO.File]::ReadAllText($candidate)
        if ($content -match $newImport -or $content -match $oldImport) {
            $target = $candidate
            break
        }
    }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $text = ''
    $exists = [System.IO.File]::Exists($target)
    if ($exists) {
        $reader = [System.IO.StreamReader]::new($target, $encoding, $true)
        try {
            $text = $reader.ReadToEnd()
            $encoding = $reader.CurrentEncoding
        } finally {
            $reader.Dispose()
        }
    }

    if ($text -match $newImport) {
        $detail = 'already imports TerminalGlyphs'
        if ($text -match $oldImport) { $detail += '; remove the Import-Module Terminal-Icons line' }
        return [pscustomobject]@{ Path = $target; Status = 'Unchanged'; Detail = $detail }
    }

    $newline = if ($text.Contains("`r`n")) { "`r`n" } elseif ($text.Contains("`n")) { "`n" } else { [Environment]::NewLine }
    if ($text -match $oldImport) {
        $updated = [regex]::Replace($text, $oldImport, '${lead}${quote}TerminalGlyphs${quote}')
        $action = 'Replace Import-Module Terminal-Icons with TerminalGlyphs'
    } else {
        $separator = if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $newline } else { '' }
        $updated = $text + $separator + '# Added by TerminalGlyphs' + $newline + 'Import-Module -Name TerminalGlyphs' + $newline
        $action = 'Add Import-Module TerminalGlyphs'
    }
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return [pscustomobject]@{ Path = $target; Status = 'Skipped'; Detail = $action }
    }

    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
    $temp = "$target.terminalglyphs.tmp"
    try {
        [System.IO.File]::WriteAllText($temp, $updated, $encoding)
        if ($exists) {
            $backup = '{0}.terminalglyphs-{1}.bak' -f $target, [DateTime]::Now.ToString('yyyyMMddHHmmss', [cultureinfo]::InvariantCulture)
            [System.IO.File]::Replace($temp, $target, $backup)
            $action += "; backup in $backup"
        } else {
            [System.IO.File]::Move($temp, $target)
        }
    } catch {
        [System.IO.File]::Delete($temp)
        throw
    }
    [pscustomobject]@{ Path = $target; Status = 'OK'; Detail = $action }
}
