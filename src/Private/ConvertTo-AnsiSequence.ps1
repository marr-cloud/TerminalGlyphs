function ConvertTo-AnsiSequence {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^#?[0-9A-Fa-f]{6}$')]
        [string]$Hex
    )

    $value = $Hex.TrimStart('#')
    $r = [Convert]::ToInt32($value.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($value.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($value.Substring(4, 2), 16)
    "$([char]27)[38;2;$r;$g;${b}m"
}
