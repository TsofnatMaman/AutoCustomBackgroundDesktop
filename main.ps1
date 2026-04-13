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

# 2. הגדרת נתיבים (וידוא ששום דבר לא ריק לפני שבכלל מתחילים)
$fName = if ($cfg.app.appFolder) { $cfg.app.appFolder } else { ".wallpaper_cache" }
$AppDir = Join-Path $env:APPDATA $fName

# יצירת תיקיית האפליקציה מיד
if (-not (Test-Path $AppDir)) { New-Item -ItemType Directory -Path $AppDir -Force | Out-Null }

$LogFolder = Join-Path $AppDir "logs"
if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null }

$CurrentDate = Get-Date -Format "yyyy-MM-dd"
$LogFile = Join-Path $LogFolder "wallpaper_$CurrentDate.log"

# 3. אתחול מערכת
Ensure-Admin -Config $cfg
Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "=== Script Started ===" -LogFile $LogFile

try {
    # הגדרת קבצי התמונה - כאן אנחנו מוודאים שהם לא ריקים
    $baseImg = [string](Join-Path $AppDir "base.jpg")
    $finalImg = [string](Join-Path $AppDir "wallpaper.jpg")

    if ([string]::IsNullOrWhiteSpace($baseImg)) { throw "Base image path is empty!" }

    # מניעת הרצה כפולה
    $mName = if ($cfg.system.mutexName) { $cfg.system.mutexName } else { "WallpaperLock" }
    $mutex = New-Object System.Threading.Mutex($false, $mName)
    if (-not $mutex.WaitOne(0)) { 
        Write-Log -Message "Another instance is running. Exiting." -LogFile $LogFile
        exit 
    }

    Add-Type -AssemblyName System.Drawing

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
    
    $rawUrl = "https://raw.githubusercontent.com/{0}/{1}/{2}/{3}" -f $u, $r, $b, $p
    $remoteImageUrl = $rawUrl.Replace(" ", "").Trim()

    Write-Log -Message "Attempting download from: <$remoteImageUrl>" -LogFile $LogFile

    # --- הקריאה לפונקציה הבעייתית ---
    # הוספנו כאן כפייה של המשתנים כטקסט (casting)
    if (Get-BaseImage -Url ([string]$remoteImageUrl) -Path ([string]$baseImg) -LogFile ([string]$LogFile)) {
        
        $text = $cfg.wallpaper.text.Replace("{days}", $daysRemaining)
        
        Export-CountdownImage -Base $baseImg -Output $finalImg -Text $text -LogFile $LogFile
        
        Set-Wallpaper -Path $finalImg
        
        Write-Log -Message "Success! Wallpaper updated." -LogFile $LogFile
    }
}
catch {
    Write-Log -Message "FATAL ERROR: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
}
finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    Write-Log -Message "=== Script Finished ===" -LogFile $LogFile
}