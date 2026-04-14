$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Import-Module "$PSScriptRoot\modules\Logging.psm1"
Import-Module "$PSScriptRoot\modules\Config.psm1"
Import-Module "$PSScriptRoot\modules\Image.psm1"
Import-Module "$PSScriptRoot\modules\System.psm1"
Import-Module "$PSScriptRoot\modules\Cleanup.psm1"

$RemoteConfigUrl = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/config.json"

function Initialize-App {
    param($cfg)

    $appFolder = if ($cfg.app.appFolder) { [string]$cfg.app.appFolder } else { ".wallpaper_cache" }
    $appDir = Join-Path $env:APPDATA $appFolder
    $logFolder = Join-Path $appDir "logs"

    Initialize-Logging -AppDir $appDir -LogFolder $logFolder

    return @{
        AppDir = $appDir
        LogFolder = $logFolder
    }
}

$bootstrapCfg = Load-Configuration -Root $PSScriptRoot -LogFile ""
$app = Initialize-App -cfg $bootstrapCfg
$LogFile = Get-LogFile -LogFolder $app.LogFolder

Write-Log -Message "=== Script Started ===" -LogFile $LogFile

$configUpdated = Update-ConfigurationFromRemote -Root $PSScriptRoot -cfg $bootstrapCfg -LogFile $LogFile -RemoteUrl $RemoteConfigUrl
$cfg = Load-Configuration -Root $PSScriptRoot -LogFile $LogFile
$app = Initialize-App -cfg $cfg
$LogFile = Get-LogFile -LogFolder $app.LogFolder

if ($configUpdated) {
    Write-Log -Message "Using refreshed config.json." -LogFile $LogFile
}
else {
    Write-Log -Message "Using local config.json because refresh failed." -Level "Warning" -LogFile $LogFile
}

$mutexName = if ($cfg.system.mutexName) { [string]$cfg.system.mutexName } else { "WallpaperScriptLock" }
$mutex = Acquire-Mutex -name $mutexName -LogFile $LogFile
if (-not $mutex) {
    Write-Log -Message "Another instance is already running. Exiting." -Level "Warning" -LogFile $LogFile
    exit
}

try {
    $targetDateValue = [string]$cfg.wallpaper.targetDate
    $targetDate = [datetime]::MinValue

    if (-not [datetime]::TryParse($targetDateValue, [ref]$targetDate)) {
        throw "Invalid wallpaper.targetDate value: '$targetDateValue'"
    }

    $daysRemaining = Get-DaysRemaining -targetDate $targetDate -LogFile $LogFile
    if ($daysRemaining -lt 0) {
        Write-Log -Message "Target date has passed. Using 0 for countdown text." -Level "Warning" -LogFile $LogFile
        $daysRemaining = 0
    }

    Write-Log -Message "Configured wallpaper time is $([string]$cfg.wallpaper.time)." -LogFile $LogFile
    Update-WallpaperFlow -cfg $cfg -AppDir $app.AppDir -LogFile $LogFile -daysRemaining $daysRemaining
}
catch {
    Write-Log -Message "Runtime failed: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
    throw
}
finally {
    if ($mutex) {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
    Write-Log -Message "=== Script Finished ===" -LogFile $LogFile
}
