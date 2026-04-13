function Remove-ScheduledTaskSafe {
    param(
        [string]$TaskName = "ChangeWallpaperEveryDay"
    )

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Scheduled task removed (if existed)."
    }
    catch {
        Write-Log "Failed removing scheduled task: $($_.Exception.Message)" -Level Warning
    }
}

function Remove-HiddenFolderSafe {
    param(
        [string]$HiddenFolder
    )

    try {
        if (Test-Path $HiddenFolder) {
            Remove-Item $HiddenFolder -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Hidden folder removed."
        }
    }
    catch {
        Write-Log "Failed removing hidden folder: $($_.Exception.Message)" -Level Warning
    }
}

function Uninstall-Project {
    param([string]$HiddenFolder)

    Write-Log "Auto-uninstall triggered."

    Remove-ScheduledTaskSafe
    Remove-HiddenFolderSafe -HiddenFolder $HiddenFolder

    exit
}

Export-ModuleMember -Function Uninstall-Project, Remove-ScheduledTaskSafe, Remove-HiddenFolderSafe