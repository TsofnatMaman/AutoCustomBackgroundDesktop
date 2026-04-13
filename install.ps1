$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- Helper function for MessageBox dialog ---
function Show-MessageBox {
    param([string]$Message, [string]$Title = "Wallpaper Installer")
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$LogFile
    )
    if ([string]::IsNullOrWhiteSpace($LogFile)) { return }
    try {
        $dir = Split-Path $LogFile -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    } catch { }
}

function Load-Configuration {
    param([string]$LogFile)
    
    # GitHub URL for config.json
    $configUrl = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/config.json"
    $tempConfigPath = Join-Path $env:TEMP "wallpaper_config.json"
    
    Write-Log -Message "Downloading configuration from: $configUrl" -Level "Info" -LogFile $LogFile
    
    try {
        Invoke-WebRequest -Uri $configUrl -OutFile $tempConfigPath -ErrorAction Stop
        Write-Log -Message "Configuration downloaded successfully" -Level "Info" -LogFile $LogFile
        
        $config = Get-Content $tempConfigPath -Raw | ConvertFrom-Json
        Write-Log -Message "Configuration parsed successfully" -Level "Info" -LogFile $LogFile
        
        return $config
    } catch {
        Write-Log -Message "Failed to download/parse configuration: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        throw $_
    }
}

function Initialize-Logging {
    param(
        [string]$AppDir,
        [string]$LogFolder
    )
    if (-not [string]::IsNullOrWhiteSpace($AppDir) -and -not (Test-Path $AppDir)) {
        New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($LogFolder) -and -not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }
}

$AppDir = Join-Path $env:APPDATA ".WallpaperProject"
$TaskName = "ChangeWallpaperEveryDay"

$LogFolder = Join-Path $AppDir "logs"
$LogFile = Join-Path $LogFolder "install.log"

Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "===== Installation started =====" -Level "Info" -LogFile $LogFile

try {
    Write-Log -Message "Loading configuration from GitHub..." -Level "Info" -LogFile $LogFile
    $cfg = Load-Configuration -LogFile $LogFile
    
    Write-Log -Message "Loading configuration variables..." -Level "Info" -LogFile $LogFile

    $u = $cfg.github.username
    $r = $cfg.github.repository
    $b = $cfg.github.branch

    Write-Log -Message "Git config loaded: user=$u repo=$r branch=$b" -Level "Info" -LogFile $LogFile

    $RepoZip = "https://github.com/$u/$r/archive/refs/heads/$b.zip"
    $TempZip = Join-Path $env:TEMP "wallpaper.zip"

    Write-Log -Message "Target repo ZIP URL: $RepoZip" -Level "Info" -LogFile $LogFile
    Write-Log -Message "Temp ZIP path: $TempZip" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Cleaning old installation directory: $AppDir" -Level "Info" -LogFile $LogFile

    if (Test-Path $AppDir) {
        Remove-Item $AppDir -Recurse -Force
        Write-Log -Message "Old directory removed successfully" -Level "Info" -LogFile $LogFile
    } else {
        Write-Log -Message "No previous installation found" -Level "Info" -LogFile $LogFile
    }

    Write-Log -Message "Creating application directory..." -Level "Info" -LogFile $LogFile
    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    Write-Log -Message "App directory ready: $AppDir" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Starting download from GitHub..." -Level "Info" -LogFile $LogFile
    Invoke-WebRequest -Uri $RepoZip -OutFile $TempZip | Out-Null
    Write-Log -Message "Download completed successfully" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Starting extraction process..." -Level "Info" -LogFile $LogFile
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $AppDir)
    Write-Log -Message "Extraction completed" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Removing temporary ZIP file..." -Level "Info" -LogFile $LogFile
    Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
    Write-Log -Message "Temporary file cleaned" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Searching extracted project folder..." -Level "Info" -LogFile $LogFile

    $projectFolder = Get-ChildItem $AppDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1

    if (-not $projectFolder) {
        Write-Log -Message "Extraction failed: no folder found" -Level "Error" -LogFile $LogFile
        throw "Extraction failed"
    }

    Write-Log -Message "Project folder detected: $($projectFolder.FullName)" -Level "Info" -LogFile $LogFile

    $main = Join-Path $projectFolder.FullName "main.ps1"

    Write-Log -Message "Checking main script: $main" -Level "Info" -LogFile $LogFile

    if (-not (Test-Path $main)) {
        Write-Log -Message "main.ps1 not found in extracted project" -Level "Error" -LogFile $LogFile
        throw "main.ps1 not found. Check repo structure."
    }

    Write-Log -Message "main.ps1 verified successfully" -Level "Info" -LogFile $LogFile

    $launcherVbs = Join-Path $projectFolder.FullName "run-main-hidden.vbs"
    $vbs = @"
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$main""", 0, False
"@
    Set-Content -Path $launcherVbs -Value $vbs -Encoding ASCII
    Write-Log -Message "Hidden VBS launcher created: $launcherVbs" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Creating scheduled task..." -Level "Info" -LogFile $LogFile

    $action = New-ScheduledTaskAction `
        -Execute "wscript.exe" `
        -Argument "`"$launcherVbs`""

    Write-Log -Message "Scheduled task action created" -Level "Info" -LogFile $LogFile

    $time = $cfg.wallpaper.time
    Write-Log -Message "Task trigger time: $time" -Level "Info" -LogFile $LogFile

    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At $time
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn

    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -Compatibility Win8 `
        -Hidden

    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel Highest

    Write-Log -Message "Scheduled task principal set for user $env:USERNAME (RunLevel=Highest)" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Registering scheduled task: $TaskName" -Level "Info" -LogFile $LogFile

    Register-ScheduledTask `
        -Action $action `
        -Trigger @($dailyTrigger, $logonTrigger) `
        -Settings $settings `
        -Principal $principal `
        -TaskName $cfg.app.taskName `
        -Description "Updates wallpaper based on countdown" `
        -Force | Out-Null

    Write-Log -Message "Scheduled task registered successfully" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Starting main script manually..." -Level "Info" -LogFile $LogFile
    Start-Process wscript.exe -ArgumentList "`"$launcherVbs`"" -WindowStyle Hidden | Out-Null
    Write-Log -Message "Main script launched" -Level "Info" -LogFile $LogFile

    Write-Log -Message "===== Installation completed successfully =====" -Level "Info" -LogFile $LogFile
    [void] (Show-MessageBox -Message "✓ ההתקנה הסתיימה בהצלחה! קישורי משימה יעודכנו כל יום בשעה $time" -Title "Wallpaper Installer - Success")
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Log -Message "INSTALLATION FAILED: $errorMsg" -Level "Error" -LogFile $LogFile
    Write-Log -Message "StackTrace: $($_.Exception.StackTrace)" -Level "Error" -LogFile $LogFile
    [void] (Show-MessageBox -Message "✗ ההתקנה נכשלה!\n\n$errorMsg" -Title "Wallpaper Installer - Error")
    exit 1
}
