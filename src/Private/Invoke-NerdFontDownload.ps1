function Invoke-NerdFontDownload {
    # The only network access of the module; tests replace it.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile
    )

    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -ErrorAction Stop
}
