Import-Module "$PSScriptRoot/Modules/Logging.psm1"
Import-Module "$PSScriptRoot/Modules/Config.psm1"
Import-Module "$PSScriptRoot/Modules/Downloads.psm1"
Import-Module "$PSScriptRoot/Modules/Countdown.psm1"
Import-Module "$PSScriptRoot/Modules/Image.psm1"
Import-Module "$PSScriptRoot/Modules/System.psm1"
Import-Module "$PSScriptRoot/Modules/WallpaperTarget.psm1"

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
        return $false
    }

    try {
        $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile
        $null = Poll-RemoteConfig -cfg $cfg -Path $configPath -LogFile $logFile
        $cfg = Get-Config -ConfigFilePath $configPath -LogFile $logFile
    }
    catch {
        Write-Log -Message "Config load failed. Keeping previous state. Error: $($_.Exception.Message)" -Level "Error" -LogFile $logFile
        return $false
    }

    try {
        $targets = Get-WallpaperTargets -Config $cfg
    }
    catch {
        Write-Log -Message "Invalid wallpaper destination: $($_.Exception.Message)" -Level "Error" -LogFile $logFile
        return $false
    }

    # Expiration cleanup must happen outside this running PowerShell process.
    # Otherwise uninstall.ps1 could delete the active script and imported modules.
    try {
        $daysRemaining = Get-DaysRemaining -cfg $cfg
        if ($daysRemaining -le 0) {
            $uninstaller = Join-Path $PSScriptRoot 'uninstall.ps1'
            if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
                throw "Uninstaller not found: $uninstaller"
            }

            # The child process waits for this PowerShell host to exit before
            # touching the scheduled task or deleting the installation folder.
            # EncodedCommand avoids a temporary helper file inside the directory
            # that is about to be removed.
            $escapedUninstaller = $uninstaller.Replace("'", "''")
            $cleanupScript = @'
$parentId = __PARENT_PID__
$uninstaller = '__UNINSTALLER_PATH__'
$logDir = Join-Path $env:LOCALAPPDATA 'WallpaperCountdown\logs'
$logPath = Join-Path $logDir 'expiration-uninstall.log'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
try {
    Wait-Process -Id $parentId -Timeout 120 -ErrorAction SilentlyContinue
    if (Get-Process -Id $parentId -ErrorAction SilentlyContinue) {
        throw "Countdown process $parentId did not exit in time; refusing to remove active files."
    }
    & $uninstaller
    if (Test-Path -LiteralPath (Join-Path $env:APPDATA '.wallpaper_countdown')) {
        throw 'Uninstaller returned but the installation folder still exists.'
    }
    Add-Content -LiteralPath $logPath -Value "[$(Get-Date -Format s)] Automatic uninstall completed." -Encoding UTF8
}
catch {
    Add-Content -LiteralPath $logPath -Value "[$(Get-Date -Format s)] Automatic uninstall failed: $($_.Exception.Message)" -Encoding UTF8
    exit 1
}
'@
            $cleanupScript = $cleanupScript.Replace('__PARENT_PID__', [string]$PID).Replace('__UNINSTALLER_PATH__', $escapedUninstaller)
            $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cleanupScript))
            $child = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-EncodedCommand', $encodedCommand
            ) -WindowStyle Hidden -PassThru -ErrorAction Stop

            Write-Log -Message "Countdown expired ($daysRemaining days). Detached uninstall launched (PID $($child.Id)); cleanup begins after current process exits." -Level "Info" -LogFile $logFile
            return $true
        }
    }
    catch {
        Write-Log -Message "Expiration check or automatic uninstall launch failed: $($_.Exception.Message)" -Level "Error" -LogFile $logFile
        return $false
    }

    # ===== Image Handling =====
    $imgPath = $cfg.github.imagePath
    $imgPathDefault = Join-Path $appDir $imgPath
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

        $srcBackgrounds = Join-Path $appDir "backgrounds"
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
        return $false
    }

    # ===== Countdown =====
    $textDaysRemain = Get-DaysText -cfg $cfg

    $renderOk = Export-CountdownImage `
        -Base $baseImageToUse `
        -Output $outImgDefault `
        -Text $textDaysRemain `
        -LogFile $logFile

    if (-not $renderOk -or -not (Test-Path $outImgDefault)) {
        Write-Log -Message "Image rendering failed. Wallpaper was not changed." -Level "Error" -LogFile $logFile
        return $false
    }

    $desktopOk = $true
    $lockScreenOk = $true
    if ($targets.desktop) {
        $desktopOk = Set-Wallpaper -Path $outImgDefault -LogFile $logFile
    }
    if ($targets.lockScreen) {
        $lockScreenOk = Set-LockScreenWallpaper -Path $outImgDefault -LogFile $logFile
        if ($lockScreenOk) {
            # Keep evidence even if config targets are later changed remotely.
            Set-Content -LiteralPath (Join-Path $appDir 'cache\lockscreen-applied.flag') -Value 'applied' -ErrorAction SilentlyContinue
        }
    }
    if (-not $desktopOk -or -not $lockScreenOk) {
        Write-Log -Message "Wallpaper update failed for at least one target." -Level "Error" -LogFile $logFile
        return $false
    }
    return $true
}

if (-not (DailyRun)) { exit 1 }