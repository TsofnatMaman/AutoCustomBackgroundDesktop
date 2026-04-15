$localPath = Join-Path $env:APPDATA ".wallpaper_countdown"

function Write-Log {
    param(
        [string]$Message
    )

    Write-Host "[UNINSTALL] $Message"
}

function Unregister-Task {
    try {
        $configPath = "$env:APPDATA\.wallpaper_countdown\Src\config.json"

        if(-not (Test-Path $configPath)){
            $taskName = "WallpaperCountdown"
        }
        else {
            $cfg = Get-Content $configPath | ConvertFrom-Json
            $taskName = $cfg.system.taskName
        }

        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Scheduled Task removed"
    }
    catch {
        Write-Log "No scheduled task found or failed to remove"
    }
}

function Remove-Folder {
    try {
        if(Test-Path $localPath) {
            Remove-Item $localPath -Recurse -Force
            Write-Log "Deleted Folder $localPath"
        }
    }
    catch {
        Write-Log "Failed to delete folder $localPath"
    }
}

Write-Log "Starting uninstall..."

Unregister-Task
Remove-Folder

Write-Log "Uninstall completed"