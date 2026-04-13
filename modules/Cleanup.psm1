function Uninstall-Project {
    param([string]$HiddenFolder)

    Write-Log "Target date reached. Initiating auto-uninstallation."

    Unregister-ScheduledTask -TaskName "ChangeWallpaperEveryDay" -Confirm:$false -ErrorAction SilentlyContinue

    $cleanupBat = Join-Path $env:TEMP "cleanup_wallpaper.bat"

@"
@echo off
timeout /t 5 > nul
rmdir /s /q "$HiddenFolder"
del "%~f0"
"@ | Set-Content $cleanupBat

    Start-Process "cmd.exe" "/c $cleanupBat" -WindowStyle Hidden
    exit
}

Export-ModuleMember -Function Uninstall-Project