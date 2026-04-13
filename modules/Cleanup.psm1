function Remove-ScheduledTaskSafe {
    param(
        [string]$TaskName = "ChangeWallpaperEveryDay",
        [string]$LogFile
    )

    Write-Log -Message "Attempting to remove scheduled task: $TaskName" -Level "Info" -LogFile $LogFile
    
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log -Message "Scheduled task removed (if existed): $TaskName" -Level "Info" -LogFile $LogFile
    }
    catch {
        Write-Log -Message "Failed removing scheduled task: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile
    }
}

function Remove-HiddenFolderSafe {
    param(
        [string]$HiddenFolder,
        [string]$LogFile
    )

    Write-Log -Message "Attempting to remove hidden folder: $HiddenFolder" -Level "Info" -LogFile $LogFile
    
    try {
        if (Test-Path $HiddenFolder) {
            Write-Log -Message "Removing folder contents..." -Level "Debug" -LogFile $LogFile
            Remove-Item $HiddenFolder -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Message "Hidden folder removed successfully: $HiddenFolder" -Level "Info" -LogFile $LogFile
        }
        else {
            Write-Log -Message "Hidden folder does not exist: $HiddenFolder" -Level "Debug" -LogFile $LogFile
        }
    }
    catch {
        Write-Log -Message "Failed removing hidden folder: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile
    }
}

function Uninstall-Project {
    param(
        [string]$HiddenFolder,
        [string]$LogFile
    )

    Write-Log -Message "=== Auto-uninstall triggered ===" -Level "Warning" -LogFile $LogFile
    Write-Log -Message "Target folder for cleanup: $HiddenFolder" -Level "Debug" -LogFile $LogFile

    Remove-ScheduledTaskSafe -LogFile $LogFile
    Remove-HiddenFolderSafe -HiddenFolder $HiddenFolder -LogFile $LogFile
    
    Write-Log -Message "=== Uninstall completed ===" -Level "Warning" -LogFile $LogFile

    exit
}

Import-Module (Join-Path $PSScriptRoot "Logging.psm1")

Export-ModuleMember -Function Uninstall-Project, Remove-ScheduledTaskSafe, Remove-HiddenFolderSafe