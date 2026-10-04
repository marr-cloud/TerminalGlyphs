function Register-FontResource {
    # Loads newly copied fonts into the current Windows session, so they can be used without signing out.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )

    $api = 'TerminalGlyphs.FontApi' -as [type]
    if (-not $api) {
        Add-Type -Namespace 'TerminalGlyphs' -Name 'FontApi' -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern int AddFontResourceW(string lpFileName);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeoutW(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        $api = 'TerminalGlyphs.FontApi' -as [type]
    }
    foreach ($file in $Path) {
        if ($api::AddFontResourceW($file) -eq 0) { throw "Windows could not load the font $file." }
    }
    $result = [UIntPtr]::Zero
    # HWND_BROADCAST, WM_FONTCHANGE, SMTO_ABORTIFHUNG, 1 second.
    [void]$api::SendMessageTimeoutW([IntPtr]0xFFFF, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$result)
}
