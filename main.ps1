[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot\modules\Logging.psm1"
Import-Module "$PSScriptRoot\modules\Config.psm1"
Import-Module "$PSScriptRoot\modules\Image.psm1"
Import-Module "$PSScriptRoot\modules\System.psm1"
Import-Module "$PSScriptRoot\modules\Cleanup.psm1"

$cfg = Load-Configuration -Root $PSScriptRoot

$AppDir = Join-Path $env:APPDATA $cfg.app.appFolder
$LogFolder = Join-Path $AppDir "logs"
$LogFile = Join-Path $LogFolder ($cfg.app.logFilePattern -replace "{date}", (Get-Date -Format "yyyy-MM-dd"))

Ensure-Admin -Config $cfg

Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "Script started." -LogFile $LogFile

try {

    $mutex = New-Object System.Threading.Mutex($false, $cfg.system.mutexName)
    if (-not $mutex.WaitOne(0)) { exit }

    Add-Type -AssemblyName System.Drawing

    $targetDate = Get-Date $cfg.wallpaper.targetDate
    $daysRemaining = ($targetDate - (Get-Date)).Days

    if ($daysRemaining -lt 0) {
        Uninstall-Project -Config $cfg -AppDir $AppDir
    }

    # שלב בניית הכתובת עם ניקוי תווים
    $username = "$($cfg.github.username)".Trim()
    $repo     = "$($cfg.github.repository)".Trim()
    $branch   = "$($cfg.github.branch)".Trim()
    $path     = "$($cfg.github.imagePath)".Trim()

    # בניית ה-URL
    $rawUrl = "https://raw.githubusercontent.com/$username/$repo/$branch/$path"
    
    # הסרת תווים בלתי נראים (כמו BOM או תווים שאינם ASCII)
    $cleanUrl = $rawUrl -replace '[^\x20-\x7E]', ''
    $remoteImageUrl = $cleanUrl.Trim()
    
    # לוג עם גרשיים כדי לזהות רווחים/תווים מיותרים
    Write-Log -Message "DEBUG: Final URL attempt is: '$remoteImageUrl'" -LogFile $LogFile

    $baseImg = Join-Path $AppDir "base.jpg"
    $finalImg = Join-Path $AppDir "wallpaper.jpg"

    if (Get-BaseImage -Url $remoteImageUrl -Path $baseImg -LogFile $LogFile) {

        $text = $cfg.wallpaper.text.Replace("{days}", $daysRemaining)

        Export-CountdownImage -Base $baseImg -Output $finalImg -Text $text -LogFile $LogFile

        Set-Wallpaper -Path $finalImg

        Write-Log -Message "Wallpaper updated ($daysRemaining days)" -LogFile $LogFile
    }

    Write-Log -Message "Finished." -LogFile $LogFile
}
catch {
    # לוג שגיאה מפורט כולל הכתובת הבעייתית בתוך גרשיים
    Write-Log -Message "ERROR: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
    Write-Log -Message "FAILED URL: '$remoteImageUrl'" -Level "Error" -LogFile $LogFile
}