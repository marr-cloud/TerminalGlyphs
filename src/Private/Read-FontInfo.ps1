function Read-FontInfo {
    <#
    .SYNOPSIS
        Reads the full name, family and Nerd Fonts version from the OpenType 'name' table of a font file.
    .DESCRIPTION
        Returns $null when the file cannot be read or has no full name. Version is $null when the version string
        has no "Nerd Fonts X.Y.Z" part. US English Windows records are preferred over other languages.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $read = {
            param([long]$Offset, [long]$Count)
            if ($Count -gt 1MB) { throw 'The name table is too large.' }
            $buffer = [byte[]]::new($Count)
            [void]$stream.Seek($Offset, [System.IO.SeekOrigin]::Begin)
            $stream.ReadExactly($buffer, 0, $buffer.Length)
            , $buffer
        }
        $u16 = { param([byte[]]$Bytes, [int]$At) ([int]$Bytes[$At] -shl 8) -bor $Bytes[$At + 1] }
        $u32 = { param([byte[]]$Bytes, [int]$At) ([long]$Bytes[$At] -shl 24) -bor ([long]$Bytes[$At + 1] -shl 16) -bor ([long]$Bytes[$At + 2] -shl 8) -bor $Bytes[$At + 3] }

        $header = & $read 0 12
        $tableCount = & $u16 $header 4
        $directory = & $read 12 (16 * $tableCount)
        $table = $null
        for ($i = 0; $i -lt $tableCount; $i++) {
            if ([System.Text.Encoding]::ASCII.GetString($directory, 16 * $i, 4) -ceq 'name') {
                $table = & $read (& $u32 $directory (16 * $i + 8)) (& $u32 $directory (16 * $i + 12))
                break
            }
        }
        if ($null -eq $table) { return $null }

        $count = & $u16 $table 2
        $storage = & $u16 $table 4
        $names = @{}
        $ranks = @{}
        for ($i = 0; $i -lt $count; $i++) {
            $record = 6 + 12 * $i
            $platform = & $u16 $table $record
            $language = & $u16 $table ($record + 4)
            $nameId = & $u16 $table ($record + 6)
            if ($platform -notin 0, 3 -or $nameId -notin 1, 4, 5, 16) { continue }
            $rank = if ($platform -eq 3 -and $language -eq 0x409) { 0 } else { 1 }
            if ($ranks.ContainsKey($nameId) -and $ranks[$nameId] -le $rank) { continue }
            $ranks[$nameId] = $rank
            $names[$nameId] = [System.Text.Encoding]::BigEndianUnicode.GetString($table, $storage + (& $u16 $table ($record + 10)), (& $u16 $table ($record + 8)))
        }
        if (-not $names.ContainsKey(4)) { return $null }

        $version = $null
        if ($names[5] -match 'Nerd Fonts (\d+\.\d+(?:\.\d+)?)') { $version = [version]$Matches[1] }
        $family = if ($names.ContainsKey(16)) { $names[16] } else { $names[1] }
        [pscustomobject]@{ FullName = $names[4]; Family = $family; Version = $version }
    } catch {
        Write-Verbose -Message "Could not read font names from ${Path}: $($_.Exception.Message)"
        $null
    } finally {
        if ($stream) { $stream.Dispose() }
    }
}
