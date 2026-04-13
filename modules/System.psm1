function Ensure-Admin {
    param($Config)

    if (-not ([Security.Principal.WindowsPrincipal]
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

        $vbs = Join-Path $env:TEMP "elevate.vbs"
        $escaped = $PSCommandPath.Replace('"','""')

@"
Set UAC = CreateObject("Shell.Application")
UAC.ShellExecute "powershell.exe", "-File ""$escaped""", "", "runas", 0
"@ | Set-Content $vbs

        Start-Process "wscript.exe" $vbs
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