function Get-FontLocation {
    <#
    .SYNOPSIS
        Returns the platform, the per-user font folder and the font folders for all users.
    .DESCRIPTION
        Directory is where fonts are installed. SystemDirectory lists the folders whose Nerd Fonts are only reported,
        because changing them needs admin rights. Nothing is read or created here.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $userProfile = [Environment]::GetFolderPath('UserProfile')
    if ($IsWindows) {
        $platform = 'Windows'
        $directory = [System.IO.Path]::Combine([Environment]::GetFolderPath('LocalApplicationData'), 'Microsoft', 'Windows', 'Fonts')
        $systemDirectory = [string[]]@([Environment]::GetFolderPath('Fonts'))
    } elseif ($IsMacOS) {
        $platform = 'MacOS'
        $directory = [System.IO.Path]::Combine($userProfile, 'Library', 'Fonts')
        $systemDirectory = [string[]]@('/Library/Fonts')
    } else {
        $platform = 'Linux'
        $dataHome = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { [System.IO.Path]::Combine($userProfile, '.local', 'share') }
        $directory = [System.IO.Path]::Combine($dataHome, 'fonts')
        $systemDirectory = [string[]]@('/usr/share/fonts', '/usr/local/share/fonts', [System.IO.Path]::Combine($userProfile, '.fonts'))
    }
    [pscustomobject]@{ Platform = $platform; Directory = $directory; SystemDirectory = $systemDirectory }
}
