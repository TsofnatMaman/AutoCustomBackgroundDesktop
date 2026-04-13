[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# טעינת מודולים
Import-Module "$PSScriptRoot\modules\Logging.psm1"
Import-Module "$PSScriptRoot\modules\Config.psm1"
Import-Module "$PSScriptRoot\modules\Image.psm1"
Import-Module "$PSScriptRoot\modules\System.psm1"
Import-Module "$PSScriptRoot\modules\Cleanup.psm1"

# 1. טעינת קונפיגורציה
$cfg = Load-Configuration -Root $PSScriptRoot

# 2. הגדרת נתיבים
$fName = if ($cfg.app.appFolder) { $cfg.app.appFolder } else { ".wallpaper_cache" }
$AppDir = Join-Path $env:APPDATA $fName
$LogFolder = Join-Path $AppDir "logs"

if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null }

$CurrentDate = Get-Date -Format "yyyy-MM-dd"
$LogFile = [string](Join-Path $LogFolder "wallpaper_$CurrentDate.log")

# 3. אתחול
Ensure-Admin -Config $cfg
Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "=== Script Started ===" -LogFile $LogFile

try {
    # וידוא נתיבי תמונות
    $baseImgPath = [string](Join-Path $AppDir "base.jpg")
    $finalImgPath = [string](Join-Path $AppDir "wallpaper.jpg")

    # מניעת הרצה כפולה
    $mName = if ($cfg.system.mutexName) { $cfg.system.mutexName } else { "WallpaperLock" }
    $mutex = New-Object System.Threading.Mutex($false, $mName)
    if (-not $mutex.WaitOne(0)) { exit }

    # חישוב ימים
    $targetDate = Get-Date $cfg.wallpaper.targetDate
    $daysRemaining = ($targetDate - (Get-Date)).Days

    if ($daysRemaining -lt 0) {
        Write-Log -Message "Target date passed." -LogFile $LogFile
        Uninstall-Project -Config $cfg -AppDir $AppDir
        return
    }

    # בניית URL
    $u = "$($cfg.github.username)".Trim()
    $r = "$($cfg.github.repository)".Trim()
    $b = "$($cfg.github.branch)".Trim()
    $p = "$($cfg.github.imagePath)".Trim()
    $remoteImageUrl = [string]"https://raw.githubusercontent.com/$u/$r/$b/$p"

    Write-Log -Message "Fetching: $remoteImageUrl" -LogFile $LogFile

    # --- קריאה לפונקציה עם המרה מפורשת לטקסט ---
    $downloadSuccess = Get-BaseImage -Url $remoteImageUrl -Path $baseImgPath -LogFile $LogFile

    if ($downloadSuccess) {
        $msgText = $cfg.wallpaper.text.Replace("{days}", $daysRemaining)
        Export-CountdownImage -Base $baseImgPath -Output $finalImgPath -Text $msgText -LogFile $LogFile
        Set-Wallpaper -Path $finalImgPath
        Write-Log -Message "Wallpaper updated successfully." -LogFile $LogFile
    }
}
catch {
    Write-Log -Message "FATAL ERROR: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
}
finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    Write-Log -Message "=== Script Finished ===" -LogFile $LogFile
}