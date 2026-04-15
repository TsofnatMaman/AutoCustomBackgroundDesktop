Import-Module "./Src/Modules/Logging.psm1"
Import-Module "./Src/Modules/Config.psm1"
Import-Module "./Src/Modules/Downloads.psm1"
Import-Module "./Src/Modules/Countdown.psm1"
Import-Module "./Src/Modules/Image.psm1"
Import-Module "./Src/Modules/System.psm1"

function DailyRun {
    $logFolder = Join-Path "$env:APPDATA" ".wallpaper_countdown\cache"
    $logFile = Initialize-Logging -LogFolder $logFolder

    # ====== Poll Config ======
    $configPath = Join-Path $env:APPDATA ".wallpaper_countdown\Src\config.json"
    $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile
    $null = Poll-RemoteConfig -cfg $cfg -Path $configPath -LogFile $logFile
    $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile

    # ===== Img Handling =====
    $imgPath = $cfg.github.imagePath
    $imgPathDefault = "$env:APPDATA/.wallpaper_countdown/Src/$imgPath"
    $outImgDefault = "$env:APPDATA/.wallpaper_countdown/cache/$imgPath"

    $null = Poll-Img -cfg $cfg -Path $imgPathDefault -LogFile $logFile
    $textDaysRemain = Get-DaysText -cfg $cfg
    Export-CountdownImage -Base $imgPathDefault -Output $outImgDefault -Text $textDaysRemain -LogFile $logFile
    Set-Wallpaper -Path $outImgDefault -LogFile $logFile
}

DailyRun
