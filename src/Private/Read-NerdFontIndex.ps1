function Read-NerdFontIndex {
    <#
    .SYNOPSIS
        Reads nerdfonts.json: the Nerd Fonts version, file prefix -> release package, and package -> SHA-256.
    #>
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    [System.IO.File]::ReadAllText($script:FontsPath) | ConvertFrom-Json -AsHashtable
}
