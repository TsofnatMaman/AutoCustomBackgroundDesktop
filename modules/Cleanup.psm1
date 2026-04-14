function Remove-ScheduledTaskSafe {
    param(
        [string]$TaskName = "ChangeWallpaperEveryDay",
        [string]$LogFile
    )

    Write-Log -Message "Attempting to remove scheduled task: $TaskName" -Level "Info" -LogFile $LogFile
    Write-Host "Removing scheduled task: $TaskName"

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "  [OK] Scheduled task removed"
        Write-Log -Message "Scheduled task removed: $TaskName" -Level "Info" -LogFile $LogFile
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)"
        Write-Log -Message "Failed removing scheduled task: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
    }
}

function Remove-HiddenFolderSafe {
    param(
        [string]$HiddenFolder,
        [string]$LogFile
    )

    Write-Log -Message "Attempting to remove hidden folder: $HiddenFolder" -Level "Info" -LogFile $LogFile
    Write-Host "Removing folder: $HiddenFolder"

    try {
        if (Test-Path $HiddenFolder) {
            Remove-Item $HiddenFolder -Recurse -Force -ErrorAction Stop
            if (-not (Test-Path $HiddenFolder)) {
                Write-Host "  [OK] Folder removed successfully"
                Write-Log -Message "Hidden folder removed: $HiddenFolder" -Level "Info" -LogFile $LogFile
            }
            else {
                Write-Host "  ERROR: Folder still exists after removal"
                Write-Log -Message "Folder still exists after removal: $HiddenFolder" -Level "Error" -LogFile $LogFile
            }
        }
        else {
            Write-Host "  Folder does not exist"
            Write-Log -Message "Folder does not exist: $HiddenFolder" -Level "Debug" -LogFile $LogFile
        }
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)"
        Write-Log -Message "Failed removing folder: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
    }
}

function Uninstall-Project {
    param(
        [string]$ProjectFolder = (Join-Path $env:APPDATA ".WallpaperProject"),
        [string]$LogFile = (Join-Path $env:TEMP "uninstall.log")
    )

    Write-Log -Message "=== Uninstall started ===" -Level "Warning" -LogFile $LogFile
    Write-Host "Starting uninstall..."

    Remove-ScheduledTaskSafe -LogFile $LogFile

    Remove-HiddenFolderSafe -HiddenFolder $ProjectFolder -LogFile $LogFile

    Write-Log -Message "=== Uninstall completed ===" -Level "Warning" -LogFile $LogFile
    Write-Host "Uninstall complete"
}

Export-ModuleMember -Function `
    Remove-ScheduledTaskSafe,
    Remove-HiddenFolderSafe,
    Uninstall-Project