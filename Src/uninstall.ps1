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

        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Log "Scheduled Task $taskName removed"
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

Unregister-Task
Remove-Folder

Write-Log "Uninstall completed"