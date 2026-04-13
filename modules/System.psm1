function Ensure-Admin {
    param($Config)
    
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "Requesting administrative privileges..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

function Set-Wallpaper {
    param([string]$Path)
    
    $code = @"
    using System;
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@
    Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
    [Wallpaper]::SystemParametersInfo(0x0014, 0, $Path, 0x01 -bor 0x02)
}

Export-ModuleMember -Function Ensure-Admin, Set-Wallpaper