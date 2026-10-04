function Get-FontLocation {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $userProfile = [Environment]::GetFolderPath('UserProfile')
    if ($IsWindows) {
        $platform = 'Windows'
        $directory = [System.IO.Path]::Combine([Environment]::GetFolderPath('LocalApplicationData'), 'Microsoft', 'Windows', 'Fonts')
    } elseif ($IsMacOS) {
        $platform = 'MacOS'
        $directory = [System.IO.Path]::Combine($userProfile, 'Library', 'Fonts')
    } else {
        $platform = 'Linux'
        $dataHome = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { [System.IO.Path]::Combine($userProfile, '.local', 'share') }
        $directory = [System.IO.Path]::Combine($dataHome, 'fonts')
    }
    [pscustomobject]@{ Platform = $platform; Directory = $directory }
}
