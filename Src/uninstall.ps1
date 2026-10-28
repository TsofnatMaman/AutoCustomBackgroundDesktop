$ConfirmPreference = 'None'

# Uninstall must target the interactive user, never a different UAC admin account.
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Run uninstall.exe without administrator elevation, from the Windows account where it was installed.'
    exit 1
}

$localPath = Join-Path $env:APPDATA ".wallpaper_countdown"

function Write-Log {
    param([string]$Message)
    Write-Host "[UNINSTALL] $Message"
}

function Set-BlackWallpaper {
    Set-ItemProperty "HKCU:\Control Panel\Colors" -Name Background -Value "0 0 0"

    Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value ""

    RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters

    Add-Type @"
using System.Runtime.InteropServices;
public class Native {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(int uAction,int uParam,string lpvParam,int fuWinIni);
}
"@

    [Native]::SystemParametersInfo(20, 0, $null, 3) | Out-Null
}

function Unregister-Task {
    try {
        $configPath = Join-Path $localPath "Src\config.json"

        if(-not (Test-Path $configPath)){
            $taskName = "ChangeWallpaperEveryDay"
        }
        else {
            $cfg = Get-Content $configPath | ConvertFrom-Json
            $taskName = $cfg.system.taskName
        }

        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $taskName = "$taskName-$sid"
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-Log "Scheduled Task $taskName removed"
        }
        else {
            Write-Log "Scheduled Task $taskName not found, skipping"
        }
    }
    catch {
        Write-Log "Failed to remove scheduled task: $($_.Exception.Message)"
        throw
    }
}

function Remove-Folder {
    try {
        if(Test-Path $localPath) {
            Remove-Item $localPath -Recurse -Force -ErrorAction Stop
            Write-Log "Deleted Folder $localPath"
        }
    }
    catch {
        Write-Log "Failed to delete folder ${localPath}: $($_.Exception.Message)"
        throw
    }
}

Write-Log "Starting uninstall..."

Set-BlackWallpaper

Unregister-Task
Remove-Folder

Write-Log "Uninstall completed"