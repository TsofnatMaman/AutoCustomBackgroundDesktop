$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RepoZipUrl = "https://github.com/TsofnatMaman/AutoCustomBackgroundDesktop/archive/refs/heads/refactor.zip"
$InstallRoot = Join-Path $env:APPDATA ".WallpaperProject"
$ProjectRoot = Join-Path $InstallRoot "AutoCustomBackgroundDesktop"
$LogFolder = Join-Path $InstallRoot "logs"
$LogFile = Join-Path $LogFolder "install.log"
$InstallMarker = Join-Path $ProjectRoot ".install-complete"

function Ensure-Directory {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Directory path is empty."
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$LogFilePath
    )

    if ([string]::IsNullOrWhiteSpace($LogFilePath)) { return }

    try {
        Ensure-Directory -Path (Split-Path -Path $LogFilePath -Parent)
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
        Add-Content -Path $LogFilePath -Value $line -Encoding UTF8
    }
    catch {
        # Logging must never break installation flow.
    }
}

function Test-ProjectLayout {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root)) {
        return $false
    }

    $requiredFiles = @("main.ps1", "config.json")
    $requiredFolders = @("modules", "backgrounds", "Tests")

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $file))) {
            return $false
        }
    }

    foreach ($folder in $requiredFolders) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $folder))) {
            return $false
        }
    }

    return $true
}

function Get-InstalledConfiguration {
    param([string]$ProjectPath)

    $configPath = Join-Path $ProjectPath "config.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "config.json not found at $configPath"
    }

    return Get-Content -Path $configPath -Raw | ConvertFrom-Json
}

function Get-DailyTriggerTime {
    param(
        [string]$TimeString,
        [string]$LogFilePath
    )

    $defaultTime = Get-Date -Hour 9 -Minute 0 -Second 0
    if ([string]::IsNullOrWhiteSpace($TimeString)) {
        Write-Log -Message "wallpaper.time is empty. Falling back to 09:00." -Level "Warning" -LogFilePath $LogFilePath
        return $defaultTime
    }

    $formats = @("HH:mm", "H:mm", "HH:mm:ss", "H:mm:ss")
    $parsed = [datetime]::MinValue
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::None

    if ([datetime]::TryParseExact($TimeString, $formats, $culture, $styles, [ref]$parsed)) {
        return Get-Date -Hour $parsed.Hour -Minute $parsed.Minute -Second 0
    }

    Write-Log -Message "wallpaper.time '$TimeString' is invalid. Falling back to 09:00." -Level "Warning" -LogFilePath $LogFilePath
    return $defaultTime
}

function Install-ProjectFilesIfNeeded {
    param(
        [string]$DestinationPath,
        [string]$MarkerPath,
        [string]$ZipUrl,
        [string]$LogFilePath
    )

    $isInstalled = Test-ProjectLayout -Root $DestinationPath
    if ($isInstalled) {
        Write-Log -Message "Existing installation detected. Skipping ZIP download." -LogFilePath $LogFilePath
        return $false
    }

    $zipPath = Join-Path $env:TEMP ("AutoCustomBackgroundDesktop_" + [guid]::NewGuid().ToString("N") + ".zip")
    $extractRoot = Join-Path $env:TEMP ("AutoCustomBackgroundDesktop_extract_" + [guid]::NewGuid().ToString("N"))

    try {
        Write-Log -Message "Downloading project ZIP from $ZipUrl" -LogFilePath $LogFilePath
        Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath -ErrorAction Stop

        Ensure-Directory -Path $extractRoot
        Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

        $repoRoot = Get-ChildItem -Path $extractRoot -Directory | Select-Object -First 1
        if (-not $repoRoot) {
            throw "ZIP extraction failed: root folder was not found."
        }

        $sourceRoot = $repoRoot.FullName
        if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot "main.ps1"))) {
            $nestedRoot = Get-ChildItem -Path $repoRoot.FullName -Directory |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "main.ps1") } |
                Select-Object -First 1

            if ($nestedRoot) {
                $sourceRoot = $nestedRoot.FullName
            }
        }

        if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot "main.ps1"))) {
            throw "ZIP extraction failed: main.ps1 was not found."
        }

        if (Test-Path -LiteralPath $DestinationPath) {
            Remove-Item -LiteralPath $DestinationPath -Recurse -Force
        }

        Ensure-Directory -Path $DestinationPath
        Copy-Item -Path (Join-Path $sourceRoot "*") -Destination $DestinationPath -Recurse -Force

        if (-not (Test-ProjectLayout -Root $DestinationPath)) {
            throw "Installed project layout is incomplete after extraction."
        }

        Set-Content -Path $MarkerPath -Value (Get-Date -Format "o") -Encoding UTF8
        Write-Log -Message "Project installed successfully at $DestinationPath" -LogFilePath $LogFilePath
        return $true
    }
    finally {
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $extractRoot) {
            Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Register-WallpaperScheduledTask {
    param(
        [string]$TaskName,
        [datetime]$DailyTime,
        [string]$MainScriptPath,
        [string]$LogFilePath
    )

    if (-not (Test-Path -LiteralPath $MainScriptPath)) {
        throw "Cannot register scheduled task. Script not found: $MainScriptPath"
    }

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $scriptDir = Split-Path -Path $MainScriptPath -Parent
    $taskExists = $null -ne (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
    $actionArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$MainScriptPath`""

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgs -WorkingDirectory $scriptDir
    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At $DailyTime
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn

    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -Compatibility Win8
    $settings.Hidden = $false

    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Description "AutoCustomBackgroundDesktop wallpaper runtime task" `
        -Action $action `
        -Trigger @($logonTrigger, $dailyTrigger) `
        -Settings $settings `
        -Principal $principal `
        -Force | Out-Null

    $status = if ($taskExists) { "updated" } else { "created" }
    Write-Log -Message "Scheduled task '$TaskName' $status for user '$currentUser' at $($DailyTime.ToString('HH:mm'))." -LogFilePath $LogFilePath
}

Ensure-Directory -Path $InstallRoot
Ensure-Directory -Path $LogFolder
Write-Log -Message "===== Installation started =====" -LogFilePath $LogFile

try {
    $downloaded = Install-ProjectFilesIfNeeded `
        -DestinationPath $ProjectRoot `
        -MarkerPath $InstallMarker `
        -ZipUrl $RepoZipUrl `
        -LogFilePath $LogFile

    if (-not (Test-ProjectLayout -Root $ProjectRoot)) {
        throw "Installation validation failed. Required project files/folders are missing."
    }

    $cfg = Get-InstalledConfiguration -ProjectPath $ProjectRoot

    $taskName = if ($cfg.app.taskName) { [string]$cfg.app.taskName } else { "ChangeWallpaperEveryDay" }
    $dailyTime = Get-DailyTriggerTime -TimeString $cfg.wallpaper.time -LogFilePath $LogFile
    $mainScriptPath = Join-Path $ProjectRoot "main.ps1"

    Register-WallpaperScheduledTask `
        -TaskName $taskName `
        -DailyTime $dailyTime `
        -MainScriptPath $mainScriptPath `
        -LogFilePath $LogFile

    $mode = if ($downloaded) { "fresh install" } else { "existing install reused" }
    Write-Log -Message "Installation completed successfully ($mode)." -LogFilePath $LogFile
    Write-Host "Installation completed successfully."
}
catch {
    Write-Log -Message $_.Exception.Message -Level "Error" -LogFilePath $LogFile
    Write-Host "Installation failed: $($_.Exception.Message)"
    exit 1
}

