$ConfirmPreference = 'None'

# Uninstall in the account where the wallpaper task runs.
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Run uninstall.exe without administrator elevation, from the Windows account where it was installed.'
    exit 1
}

$localPath = Join-Path $env:APPDATA '.wallpaper_countdown'

function Write-Log {
    param([string]$Message)
    Write-Host "[UNINSTALL] $Message"
}

function Set-BlackWallpaper {
    Set-ItemProperty 'HKCU:\Control Panel\Colors' -Name Background -Value '0 0 0'
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value ''
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

function Reset-LockScreen {
    # A custom lock screen cannot be unset via a supported API.
    # Replace an app-managed image with a stock Windows image.
    $marker = Join-Path $localPath 'cache\lockscreen-applied.flag'
    $wasApplied = Test-Path -LiteralPath $marker

    if (-not $wasApplied) {
        $configPath = Join-Path $localPath 'Src\config.json'
        if (Test-Path -LiteralPath $configPath) {
            try {
                $config = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $wasApplied = ($config.wallpaper.targets.lockScreen -eq $true)
            }
            catch {
                Write-Log "Could not check lock-screen configuration: $($_.Exception.Message)"
            }
        }
    }

    if (-not $wasApplied) {
        Write-Log 'No lock-screen update recorded; leaving the existing lock screen unchanged.'
        return
    }

    $screenFolder = Join-Path $env:WINDIR 'Web\Screen'
    $stock = Join-Path $screenFolder 'img100.jpg'
    if (-not (Test-Path -LiteralPath $stock -PathType Leaf)) {
        $stock = Get-ChildItem -LiteralPath $screenFolder -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '^\.(jpg|jpeg|png)$' } |
            Sort-Object Name |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $stock) {
        Write-Log 'Windows stock lock-screen image not found; existing lock screen left unchanged.'
        return
    }

    try {
        Import-Module (Join-Path $localPath 'Src\Modules\System.psm1') -ErrorAction Stop
        $resetLog = Join-Path $env:LOCALAPPDATA 'WallpaperCountdown\logs\uninstall.log'
        $logDir = Split-Path -Parent $resetLog
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        if (-not (Set-LockScreenWallpaper -Path $stock -LogFile $resetLog)) {
            throw "Windows rejected lock-screen reset; see $resetLog"
        }
        Write-Log "Lock screen restored to Windows stock image: $stock"
    }
    catch {
        Write-Log "Lock-screen reset failed; leaving Windows settings intact: $($_.Exception.Message)"
    }
}

function Unregister-Task {
    try {
        $configPath = Join-Path $localPath 'Src\config.json'
        if (-not (Test-Path -LiteralPath $configPath)) {
            $taskName = 'ChangeWallpaperEveryDay'
        }
        else {
            $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
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
        if (Test-Path -LiteralPath $localPath) {
            Remove-Item -LiteralPath $localPath -Recurse -Force -ErrorAction Stop
            Write-Log "Deleted Folder $localPath"
        }
    }
    catch {
        Write-Log "Failed to delete folder ${localPath}: $($_.Exception.Message)"
        throw
    }
}

Write-Log 'Starting uninstall...'
Set-BlackWallpaper
Reset-LockScreen
Unregister-Task
Remove-Folder
Write-Log 'Uninstall completed'
