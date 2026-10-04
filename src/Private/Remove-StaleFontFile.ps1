function Remove-StaleFontFile {
    <#
    .SYNOPSIS
        Deletes font files renamed by Install-NerdFontFile once Windows has restarted.
    .DESCRIPTION
        The Windows font cache keeps using a renamed font file until the next restart; deleting it earlier makes
        apps fall back to other fonts. A renamed file whose original is missing is restored instead.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$FontDirectory,

        [datetime]$BootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    )

    $result = [pscustomobject]@{ Removed = 0; Restored = 0; Pending = 0 }
    if (-not [System.IO.Directory]::Exists($FontDirectory)) { return $result }
    $boot = $BootTime.ToUniversalTime()
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $files = Get-ChildItem -LiteralPath $FontDirectory -Filter '*.old-nerdfont' -File -ErrorAction Ignore | Sort-Object -Property Name -Descending
    foreach ($file in $files) {
        if ($file.Name -notmatch '^(?<original>.+)\.(?<stamp>\d{14})\.old-nerdfont$') { continue }
        $originalName = $Matches['original']
        $renamedAt = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($Matches['stamp'], 'yyyyMMddHHmmss', [cultureinfo]::InvariantCulture, $styles, [ref]$renamedAt)) { continue }
        $original = [System.IO.Path]::Combine($file.DirectoryName, $originalName)

        if (-not [System.IO.File]::Exists($original)) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Restore missing font $originalName")) {
                try {
                    Move-Item -LiteralPath $file.FullName -Destination $original -ErrorAction Stop
                    $result.Restored++
                } catch {
                    $result.Pending++
                }
            }
            continue
        }
        if ($boot -le $renamedAt) {
            $result.Pending++
            continue
        }
        if ($PSCmdlet.ShouldProcess($file.FullName, 'Delete replaced font file')) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $result.Removed++
            } catch {
                $result.Pending++
            }
        }
    }
    $result
}
