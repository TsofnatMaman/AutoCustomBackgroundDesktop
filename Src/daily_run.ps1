Import-Module "./Src/Modules/Logging.psm1"
Import-Module "./Src/Modules/Config.psm1"
Import-Module "./Src/Modules/Downloads.psm1"
Import-Module "./Src/Modules/Countdown.psm1"
Import-Module "./Src/Modules/Image.psm1"
Import-Module "./Src/Modules/System.psm1"

function DailyRun {
    $appDir = Join-Path "$env:APPDATA" ".wallpaper_countdown"

    $logFolder = Join-Path $appDir "cache"
    $logFile = Initialize-Logging -LogFolder $logFolder

    # ====== Poll Config ======
    $configPath = Join-Path $appDir "Src\config.json"
    $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile
    $null = Poll-RemoteConfig -cfg $cfg -Path $configPath -LogFile $logFile
    $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile

    # ===== Img Handling =====
    $imgPath = $cfg.github.imagePath
    $imgPathDefault = Join-Path $appDir "Src/$imgPath"
    $outImgDefault = Join-Path $appDir "cache/$imgPath"

    $null = Poll-Img -cfg $cfg -Path $imgPathDefault -LogFile $logFile

    # if days ramain equals 0 - uninstall
    $dayRemain = Get-DaysRemaining $cfg
    if($dayRemain -eq 0) {
        Start-Process powershell -ArgumentList "-File `"$appDir\Src\uninstall.ps1`"" -WindowStyle Hidden
        return
    }
    
    $textDaysRemain = Get-DaysText -cfg $cfg
    Export-CountdownImage -Base $imgPathDefault -Output $outImgDefault -Text $textDaysRemain -LogFile $logFile
    Set-Wallpaper -Path $outImgDefault -LogFile $logFile
}

DailyRun
