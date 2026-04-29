Import-Module "$PSScriptRoot/Modules/Logging.psm1"
Import-Module "$PSScriptRoot/Modules/Config.psm1"
Import-Module "$PSScriptRoot/Modules/Downloads.psm1"
Import-Module "$PSScriptRoot/Modules/Countdown.psm1"
Import-Module "$PSScriptRoot/Modules/Image.psm1"
Import-Module "$PSScriptRoot/Modules/System.psm1"

function DailyRun {
    $appDir = Join-Path "$env:APPDATA" ".wallpaper_countdown"

    $logFolder = Join-Path $appDir "cache"
    $logFile = Initialize-Logging -LogFolder $logFolder

    # ====== Config Handling ======
    $configPath = Join-Path $appDir "Src\config.json"

    if (-not (Test-Path $configPath)) {
        Write-Log -Message "Config file does not exist: $configPath" -Level "Error" -LogFile $logFile
        return
    }

    try {
        $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile
        $null = Poll-RemoteConfig -cfg $cfg -Path $configPath -LogFile $logFile
        $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile
    }
    catch {
        Write-Log -Message "Config load failed. Keeping previous state. Error: $($_.Exception.Message)" -Level "Error" -LogFile $logFile
        return
    }

    # ===== Image Handling =====
    $imgPath = $cfg.github.imagePath
    $imgPathDefault = Join-Path $appDir "Src\$imgPath"
    $outImgDefault = Join-Path $appDir "cache\$imgPath"

    $imgDownloadOk = Poll-Img -cfg $cfg -Path $imgPathDefault -LogFile $logFile

    if (-not $imgDownloadOk) {
        Write-Log -Message "Image refresh failed. Using existing clean image: $imgPathDefault" -Level "Warning" -LogFile $logFile
    }

    if (-not (Test-Path $imgPathDefault)) {
        Write-Log -Message "No existing clean image found: $imgPathDefault" -Level "Error" -LogFile $logFile
        return
    }

    # ===== Countdown =====
    $dayRemain = Get-DaysRemaining $cfg

    if ($dayRemain -le 0) {
        Write-Host "The program is finished, to uninstall - copy to another folder and run the file %APPDATA%\.wallpaper_countdown\Src\uninstall.exe We invite you to use the program again - github.com/$($cfg.github.username)/$($cfg.github.repository)"
        return
    }

    $textDaysRemain = Get-DaysText -cfg $cfg

    $renderOk = Export-CountdownImage `
        -Base $imgPathDefault `
        -Output $outImgDefault `
        -Text $textDaysRemain `
        -LogFile $logFile

    if (-not $renderOk -or -not (Test-Path $outImgDefault)) {
        Write-Log -Message "Image rendering failed. Wallpaper was not changed." -Level "Error" -LogFile $logFile
        return
    }

    Set-Wallpaper -Path $outImgDefault -LogFile $logFile
}

DailyRun