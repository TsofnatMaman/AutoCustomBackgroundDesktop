$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot\modules\Logging.psm1"
Import-Module "$PSScriptRoot\modules\Config.psm1"

$AppDir = Join-Path $env:APPDATA ".WallpaperProject"
$TaskName = "ChangeWallpaperEveryDay"

$LogFolder = Join-Path $AppDir "logs"
$LogFile = Join-Path $LogFolder "install.log"

Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "===== Installation started =====" -Level "Info" -LogFile $LogFile

try {
    Write-Log -Message "Loading configuration from config.json..." -Level "Info" -LogFile $LogFile
    $cfg = Load-Configuration -Root $PSScriptRoot -LogFile $LogFile
    
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
    Invoke-WebRequest -Uri $RepoZip -OutFile $TempZip
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

    Write-Log -Message "Creating scheduled task..." -Level "Info" -LogFile $LogFile

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$main`""

    Write-Log -Message "Scheduled task action created" -Level "Info" -LogFile $LogFile

    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive

    Write-Log -Message "Scheduled task principal set for user $env:USERNAME" -Level "Info" -LogFile $LogFile

    $time = $cfg.wallpaper.time
    Write-Log -Message "Task trigger time: $time" -Level "Info" -LogFile $LogFile

    $trigger = New-ScheduledTaskTrigger -Daily -At $time

    Write-Log -Message "Registering scheduled task: $TaskName" -Level "Info" -LogFile $LogFile

    Register-ScheduledTask `
        -Action $action `
        -Trigger $trigger `
        -TaskName $cfg.app.taskName `
        -Description "Updates wallpaper based on countdown" `
        -Force

    Write-Log -Message "Scheduled task registered successfully" -Level "Info" -LogFile $LogFile

    Write-Log -Message "Starting main script manually..." -Level "Info" -LogFile $LogFile
    Start-Process powershell.exe "-File `"$main`""

    Write-Log -Message "Main script launched" -Level "Info" -LogFile $LogFile

    Write-Log -Message "===== Installation completed successfully =====" -Level "Info" -LogFile $LogFile
}
catch {
    Write-Log -Message "INSTALLATION FAILED: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
    Write-Log -Message "StackTrace: $($_.Exception.StackTrace)" -Level "Error" -LogFile $LogFile
    throw
}