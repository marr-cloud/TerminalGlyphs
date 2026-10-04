function Get-FontLocation {
    <#
    .SYNOPSIS
        Returns the platform, the per-user font folders and the font folders for all users.
    .DESCRIPTION
        Directory is where new fonts are installed. UserDirectory lists every per-user folder whose Nerd Fonts are
        updated in place (Directory first; on Linux also the legacy ~/.fonts). SystemDirectory lists the folders whose
        Nerd Fonts are only reported, because changing them needs admin rights. Nothing is read or created here.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $userProfile = [Environment]::GetFolderPath('UserProfile')
    if ($IsWindows) {
        $platform = 'Windows'
        $directory = [System.IO.Path]::Combine([Environment]::GetFolderPath('LocalApplicationData'), 'Microsoft', 'Windows', 'Fonts')
        $userDirectory = [string[]]@($directory)
        $systemDirectory = [string[]]@([Environment]::GetFolderPath('Fonts'))
    } elseif ($IsMacOS) {
        $platform = 'MacOS'
        $directory = [System.IO.Path]::Combine($userProfile, 'Library', 'Fonts')
        $userDirectory = [string[]]@($directory)
        $systemDirectory = [string[]]@('/Library/Fonts')
    } else {
        $platform = 'Linux'
        $dataHome = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { [System.IO.Path]::Combine($userProfile, '.local', 'share') }
        $directory = [System.IO.Path]::Combine($dataHome, 'fonts')
        $userDirectory = [string[]]@($directory, [System.IO.Path]::Combine($userProfile, '.fonts'))
        $systemDirectory = [string[]]@('/usr/share/fonts', '/usr/local/share/fonts')
    }
    [pscustomobject]@{ Platform = $platform; Directory = $directory; UserDirectory = $userDirectory; SystemDirectory = $systemDirectory }
}
