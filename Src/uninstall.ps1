$ConfirmPreference = 'None'

$localPath = Join-Path $env:APPDATA ".wallpaper_countdown"

$systemModulePath = Join-Path $localPath "Src\Modules\System.psm1"
if (Test-Path $systemModulePath) {
    Import-Module $systemModulePath -Force
}

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
    $backupFile = Join-Path $localPath "backup\original_wallpaper.json"

    if (-not (Test-Path $backupFile)) {
        Write-Log "No wallpaper backup found, skipping restore"
        return
    }

    try {
        $result = Restore-Wallpaper -BackupFile $backupFile
        if ($result) {
            Write-Log "Wallpaper restored successfully"
        }
        else {
            Write-Log "Failed to restore wallpaper (Restore-Wallpaper returned false)"
        }
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