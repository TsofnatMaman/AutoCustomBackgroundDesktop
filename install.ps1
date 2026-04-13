$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot\modules\Logging.psm1"

$AppDir = Join-Path $env:APPDATA ".WallpaperProject"
$TaskName = "ChangeWallpaperEveryDay"

$LogFolder = Join-Path $AppDir "logs"
$LogFile = Join-Path $LogFolder "install.log"

Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log "===== Installation started =====" "Info" $LogFile

try {
    Write-Log "Loading configuration variables..." "Info" $LogFile

    $u = $cfg.github.username
    $r = $cfg.github.repository
    $b = $cfg.github.branch

    Write-Log "Git config loaded: user=$u repo=$r branch=$b" "Info" $LogFile

    $RepoZip = "https://github.com/$u/$r/archive/refs/heads/$b.zip"
    $TempZip = Join-Path $env:TEMP "wallpaper.zip"

    Write-Log "Target repo ZIP URL: $RepoZip" "Info" $LogFile
    Write-Log "Temp ZIP path: $TempZip" "Info" $LogFile

    Write-Log "Cleaning old installation directory: $AppDir" "Info" $LogFile

    if (Test-Path $AppDir) {
        Remove-Item $AppDir -Recurse -Force
        Write-Log "Old directory removed successfully" "Success" $LogFile
    } else {
        Write-Log "No previous installation found" "Info" $LogFile
    }

    Write-Log "Creating application directory..." "Info" $LogFile
    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    Write-Log "App directory ready: $AppDir" "Success" $LogFile

    Write-Log "Starting download from GitHub..." "Info" $LogFile
    Invoke-WebRequest -Uri $RepoZip -OutFile $TempZip
    Write-Log "Download completed successfully" "Success" $LogFile

    Write-Log "Starting extraction process..." "Info" $LogFile
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $AppDir)
    Write-Log "Extraction completed" "Success" $LogFile

    Write-Log "Removing temporary ZIP file..." "Info" $LogFile
    Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
    Write-Log "Temporary file cleaned" "Success" $LogFile

    Write-Log "Searching extracted project folder..." "Info" $LogFile

    $projectFolder = Get-ChildItem $AppDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1

    if (-not $projectFolder) {
        Write-Log "Extraction failed: no folder found" "Error" $LogFile
        throw "Extraction failed"
    }

    Write-Log "Project folder detected: $($projectFolder.FullName)" "Success" $LogFile

    $main = Join-Path $projectFolder.FullName "main.ps1"

    Write-Log "Checking main script: $main" "Info" $LogFile

    if (-not (Test-Path $main)) {
        Write-Log "main.ps1 not found in extracted project" "Error" $LogFile
        throw "main.ps1 not found. Check repo structure."
    }

    Write-Log "main.ps1 verified successfully" "Success" $LogFile

    Write-Log "Creating scheduled task..." "Info" $LogFile

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$main`""

    Write-Log "Scheduled task action created" "Info" $LogFile

    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive

    Write-Log "Scheduled task principal set for user $env:USERNAME" "Info" $LogFile

    $time = $cfg.wallpaper.time
    Write-Log "Task trigger time: $time" "Info" $LogFile

    $trigger = New-ScheduledTaskTrigger -Daily -At $time

    Write-Log "Registering scheduled task: $TaskName" "Info" $LogFile

    Register-ScheduledTask `
        -Action $action `
        -Trigger $trigger `
        -TaskName $cfg.app.taskName `
        -Description "Updates wallpaper based on countdown" `
        -Force

    Write-Log "Scheduled task registered successfully" "Success" $LogFile

    Write-Log "Starting main script manually..." "Info" $LogFile
    Start-Process powershell.exe "-File `"$main`""

    Write-Log "Main script launched" "Success" $LogFile

    Write-Log "===== Installation completed successfully =====" "Success" $LogFile
}
catch {
    Write-Log "INSTALLATION FAILED: $($_.Exception.Message)" "Error" $LogFile
    Write-Log "StackTrace: $($_.Exception.StackTrace)" "Error" $LogFile
    throw
}