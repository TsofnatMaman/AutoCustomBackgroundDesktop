[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# טעינת מודולים
Import-Module "$PSScriptRoot\modules\Logging.psm1"
Import-Module "$PSScriptRoot\modules\Config.psm1"
Import-Module "$PSScriptRoot\modules\Image.psm1"
Import-Module "$PSScriptRoot\modules\System.psm1"
Import-Module "$PSScriptRoot\modules\Cleanup.psm1"

# טעינת קונפיגורציה
$cfg = Load-Configuration -Root $PSScriptRoot

# הגדרת נתיבים
$AppDir = Join-Path $env:APPDATA $cfg.app.appFolder
$LogFolder = Join-Path $AppDir "logs"
$CurrentDate = Get-Date -Format "yyyy-MM-dd"
$LogFile = Join-Path $LogFolder ($cfg.app.logFilePattern -replace "{date}", $CurrentDate)

# --- שלב קריטי: יצירת תיקיית הלוגים אם היא לא קיימת ---
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

Ensure-Admin -Config $cfg
Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "=== Script Started ===" -LogFile $LogFile

try {
    # מניעת הרצה כפולה
    $mutex = New-Object System.Threading.Mutex($false, $cfg.system.mutexName)
    if (-not $mutex.WaitOne(0)) { 
        Write-Log -Message "Another instance is running. Exiting." -LogFile $LogFile
        exit 
    }

    Add-Type -AssemblyName System.Drawing

    # חישוב ימים
    $targetDate = Get-Date $cfg.wallpaper.targetDate
    $daysRemaining = ($targetDate - (Get-Date)).Days

    if ($daysRemaining -lt 0) {
        Write-Log -Message "Target date passed. Uninstalling." -LogFile $LogFile
        Uninstall-Project -Config $cfg -AppDir $AppDir
        return
    }

    # בניית URL בטוחה (ללא רווחים ותווים נסתרים)
    $u = "$($cfg.github.username)".Trim()
    $r = "$($cfg.github.repository)".Trim()
    $b = "$($cfg.github.branch)".Trim()
    $p = "$($cfg.github.imagePath)".Trim()
    
    $rawUrl = "https://raw.githubusercontent.com/{0}/{1}/{2}/{3}" -f $u, $r, $b, $p
    $remoteImageUrl = $rawUrl.Replace(" ", "").Trim()

    Write-Log -Message "Attempting download from: <$remoteImageUrl>" -LogFile $LogFile

    $baseImg = Join-Path $AppDir "base.jpg"
    $finalImg = Join-Path $AppDir "wallpaper.jpg"

    # הורדה ועדכון
    if (Get-BaseImage -Url $remoteImageUrl -Path $baseImg -LogFile $LogFile) {
        $text = $cfg.wallpaper.text.Replace("{days}", $daysRemaining)
        Export-CountdownImage -Base $baseImg -Output $finalImg -Text $text -LogFile $LogFile
        Set-Wallpaper -Path $finalImg
        Write-Log -Message "Success! Wallpaper updated." -LogFile $LogFile
    } else {
        Write-Log -Message "Failed to download image." -Level "Error" -LogFile $LogFile
    }
}
catch {
    Write-Log -Message "FATAL ERROR: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
}
finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    Write-Log -Message "=== Script Finished ===" -LogFile $LogFile
}