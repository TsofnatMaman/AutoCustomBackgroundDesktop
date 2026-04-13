function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] 
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

        $vbsPath = Join-Path $env:TEMP "elevate.vbs"
        $escaped = $PSCommandPath.Replace("""","""""")

        @"
Set sh = CreateObject("Shell.Application")
sh.ShellExecute "powershell.exe", "-File ""$escaped""", "", "runas", 0
"@ | Set-Content $vbsPath

        Start-Process "wscript.exe" $vbsPath
        exit
    }
}

function Set-Wallpaper {
    param([string]$Path)

    Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    [Wallpaper]::SystemParametersInfo(20, 0, $Path, 3) | Out-Null
}

Export-ModuleMember -Function Ensure-Admin, Set-Wallpaper