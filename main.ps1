[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# טעינת מודולים
Import-Module "$PSScriptRoot\modules\Logging.psm1"
Import-Module "$PSScriptRoot\modules\Config.psm1"
Import-Module "$PSScriptRoot\modules\Image.psm1"
Import-Module "$PSScriptRoot\modules\System.psm1"
Import-Module "$PSScriptRoot\modules\Cleanup.psm1"

$cfg = Load-Configuration -Root $PSScriptRoot

$AppDir = Join-Path $env:APPDATA $cfg.app.appFolder
$LogFolder = Join-Path $AppDir "logs"
$CurrentDate = Get-Date -Format "yyyy-MM-dd"
$LogFile = Join-Path $LogFolder ($cfg.app.logFilePattern -replace "{date}", $CurrentDate)

Ensure-Admin -Config $cfg
Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "--- Script execution started ---" -LogFile $LogFile

try {
    $mutex = New-Object System.Threading.Mutex($false, $cfg.system.mutexName)
    if (-not $mutex.WaitOne(0)) { 
        Write-Log -Message "Another instance is already running. Exiting." -LogFile $LogFile
        exit 
    }

    Add-Type -AssemblyName System.Drawing

    $targetDate = Get-Date $cfg.wallpaper.targetDate
    $daysRemaining = ($targetDate - (Get-Date)).Days

    if ($daysRemaining -lt 0) {
        Write-Log -Message "Target date passed. Uninstalling..." -LogFile $LogFile
        Uninstall-Project -Config $cfg -AppDir $AppDir
        return
    }

    # בניית URL בצורה בטוחה לחלוטין
    $u = $cfg.github.username.ToString().Trim()
    $r = $cfg.github.repository.ToString().Trim()
    $b = $cfg.github.branch.ToString().Trim()
    $p = $cfg.github.imagePath.ToString().Trim()

    # שימוש בפורמט מחרוזת כדי למנוע בעיות פענוח
    $remoteImageUrl = "https://raw.githubusercontent.com/{0}/{1}/{2}/{3}" -f $u, $r, $b, $p
    $remoteImageUrl = $remoteImageUrl.Replace(" ", "") # הסרת רווחים פיזית

    Write-Log -Message "Final URL check: <$remoteImageUrl>" -LogFile $LogFile

    $baseImg = Join-Path $AppDir "base.jpg"
    $finalImg = Join-Path $AppDir "wallpaper.jpg"

    # ניסיון הורדה
    if (Get-BaseImage -Url $remoteImageUrl -Path $baseImg -LogFile $LogFile) {
        $text = $cfg.wallpaper.text.Replace("{days}", $daysRemaining)
        Export-CountdownImage -Base $baseImg -Output $finalImg -Text $text -LogFile $LogFile
        Set-Wallpaper -Path $finalImg
        Write-Log -Message "Wallpaper updated successfully. Days remaining: $daysRemaining" -LogFile $LogFile
    } else {
        Write-Log -Message "Failed to fetch image from GitHub." -Level "Warning" -LogFile $LogFile
    }

}
catch {
    $errMsg = $_.Exception.Message
    Write-Log -Message "CRITICAL ERROR: $errMsg" -Level "Error" -LogFile $LogFile
}
finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    Write-Log -Message "--- Script execution finished ---" -LogFile $LogFile
}