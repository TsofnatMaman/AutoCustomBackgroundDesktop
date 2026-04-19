$ConfirmPreference = 'None'

$localPath = Join-Path $env:APPDATA ".wallpaper_countdown"

function Write-Log {
    param(
        [string]$Message
    )

    Write-Host "[UNINSTALL] $Message"
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

function Restore-OriginalWallpaper {
    $backupFile = Join-Path $localPath "backup\original_wallpaper.txt"

    if (-not (Test-Path $backupFile)) {
        Write-Log "No wallpaper backup found, skipping restore"
        return
    }

    $originalPath = (Get-Content $backupFile -Raw).Trim()

    if ([string]::IsNullOrWhiteSpace($originalPath)) {
        Write-Log "Wallpaper backup is empty, skipping restore"
        return
    }

    try {
        $code = @"
        using System;
        using System.Runtime.InteropServices;
        public class WallpaperRestorer {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@
        if (-not ("WallpaperRestorer" -as [type])) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }

        [WallpaperRestorer]::SystemParametersInfo(0x0014, 0, $originalPath, 0x01 -bor 0x02) | Out-Null
        Write-Log "Wallpaper restored to: $originalPath"
    }
    catch {
        Write-Log "Failed to restore wallpaper: $($_.Exception.Message)"
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

Unregister-Task
Restore-OriginalWallpaper
Remove-Folder

Write-Log "Uninstall completed"