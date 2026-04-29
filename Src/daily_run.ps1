Import-Module "$PSScriptRoot/Modules/Logging.psm1"
Import-Module "$PSScriptRoot/Modules/Config.psm1"
Import-Module "$PSScriptRoot/Modules/Downloads.psm1"
Import-Module "$PSScriptRoot/Modules/Countdown.psm1"
Import-Module "$PSScriptRoot/Modules/Image.psm1"
Import-Module "$PSScriptRoot/Modules/System.psm1"

function Get-FirstValidImageFromFolder {
    param(
        [string]$Folder,
        [string]$LogFile = $null
    )

    if (-not (Test-Path $Folder)) {
        return $null
    }

    $files = Get-ChildItem -Path $Folder -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|bmp)$' } |
        Sort-Object LastWriteTime -Descending

    foreach ($file in $files) {
        if (Test-ImageFile -Path $file.FullName) {
            Write-Log -Message "Found valid fallback image: $($file.FullName)" -Level "Info" -LogFile $LogFile
            return $file.FullName
        }
    }

    return $null
}

function DailyRun {
    $appDir = Join-Path "$env:APPDATA" ".wallpaper_countdown"

    $logFolder = Join-Path $appDir "cache"
    $logFile = Initialize-Logging -LogFolder $logFolder

    # ===== Config Handling =====
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

    $lastValidDir = Join-Path $appDir "cache\last-valid"
    $lastValidImage = Join-Path $lastValidDir "base.jpg"

    if (-not (Test-Path $lastValidDir)) {
        New-Item -ItemType Directory -Path $lastValidDir -Force | Out-Null
    }

    $imgDownloadOk = Poll-Img -cfg $cfg -Path $imgPathDefault -LogFile $logFile

    if (-not $imgDownloadOk) {
        Write-Log -Message "Image refresh failed. Will try existing/last valid image." -Level "Warning" -LogFile $logFile
    }

    $baseImageToUse = $null

    if ((Test-Path $imgPathDefault) -and (Test-ImageFile -Path $imgPathDefault)) {
        $baseImageToUse = $imgPathDefault
        Copy-Item -Path $imgPathDefault -Destination $lastValidImage -Force
        Write-Log -Message "Using current clean image and saved it as last valid image: $imgPathDefault" -Level "Info" -LogFile $logFile
    }
    elseif ((Test-Path $lastValidImage) -and (Test-ImageFile -Path $lastValidImage)) {
        $baseImageToUse = $lastValidImage
        Write-Log -Message "Using last valid cached image: $lastValidImage" -Level "Warning" -LogFile $logFile
    }
    else {
        Write-Log -Message "Current image and last-valid image are unavailable. Searching for any valid previous image." -Level "Warning" -LogFile $logFile

        $srcBackgrounds = Join-Path $appDir "Src\backgrounds"
        $cacheBackgrounds = Join-Path $appDir "cache\backgrounds"

        $fallbackImage = Get-FirstValidImageFromFolder -Folder $srcBackgrounds -LogFile $logFile

        if (-not $fallbackImage) {
            $fallbackImage = Get-FirstValidImageFromFolder -Folder $cacheBackgrounds -LogFile $logFile
        }

        if ($fallbackImage) {
            $baseImageToUse = $fallbackImage
            Copy-Item -Path $fallbackImage -Destination $lastValidImage -Force
            Write-Log -Message "Using fallback image and saved it as last valid image: $fallbackImage" -Level "Warning" -LogFile $logFile
        }
    }

    if (-not $baseImageToUse) {
        Write-Log -Message "No valid image found at all. Wallpaper was not changed." -Level "Error" -LogFile $logFile
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
        -Base $baseImageToUse `
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