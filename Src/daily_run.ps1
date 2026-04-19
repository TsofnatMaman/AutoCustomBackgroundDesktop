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
    if($dayRemain -le 0) {
        Write-Host "The program is finished, to uninstall - copy to another folder and run the file %APPDATA%\.wallpaper_countdown\Src\uninstall.exe We invite you to use the program again - github.com/TsofnatMaman/AutoCustomBackgroundDesktop"
        # Start-Process powershell -ArgumentList "-File `"$appDir\Src\uninstall.ps1`"" -WindowStyle Hidden
        return
    }
    
    # ===== Backup original wallpaper (only once, before first modification) =====
    $backupFile = Join-Path $appDir "backup\original_wallpaper.txt"
    if (-not (Test-Path $backupFile)) {
        $null = Backup-Wallpaper -BackupFile $backupFile -LogFile $logFile
    }

    $textDaysRemain = Get-DaysText -cfg $cfg
    Export-CountdownImage -Base $imgPathDefault -Output $outImgDefault -Text $textDaysRemain -LogFile $logFile
    Set-Wallpaper -Path $outImgDefault -LogFile $logFile
}

DailyRun