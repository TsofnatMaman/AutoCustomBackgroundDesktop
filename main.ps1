function Initialize-App {
    param($cfg)

    $fName = if ($cfg.app.appFolder) { $cfg.app.appFolder } else { ".wallpaper_cache" }
    $AppDir = Join-Path $env:APPDATA $fName
    $LogFolder = Join-Path $AppDir "logs"

    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }

    return @{
        AppDir = $AppDir
        LogFolder = $LogFolder
    }
}

Import-Module "$PSScriptRoot\modules\Logging.psm1" -Force
Import-Module "$PSScriptRoot\modules\Config.psm1" -Force
Import-Module "$PSScriptRoot\modules\Image.psm1" -Force
Import-Module "$PSScriptRoot\modules\System.psm1" -Force
Import-Module "$PSScriptRoot\modules\Cleanup.psm1" -Force

$cfg = Load-Configuration -Root $PSScriptRoot

Ensure-Admin

$app = Initialize-App $cfg
$LogFile = Get-LogFile $app.LogFolder

Initialize-Logging -AppDir $app.AppDir -LogFolder $app.LogFolder
Write-Log -Message "=== Script Started ===" -LogFile $LogFile

$mutexName = if ($cfg.system.mutexName) { $cfg.system.mutexName } else { "WallpaperLock" }
$mutex = Acquire-Mutex $mutexName
if (-not $mutex) { exit }

try {
    $daysRemaining = Get-DaysRemaining (Get-Date $cfg.wallpaper.targetDate)

    if ($daysRemaining -lt 0) {
        Write-Log -Message "Target date passed." -LogFile $LogFile
        Uninstall-Project -Config $cfg -AppDir $app.AppDir
        return
    }

    Update-WallpaperFlow $cfg $app.AppDir $LogFile $daysRemaining
}
finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    Write-Log -Message "=== Script Finished ===" -LogFile $LogFile
}