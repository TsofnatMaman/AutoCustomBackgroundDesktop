$githubUsername = "TsofnatMaman"
$githubRepoName = "AutoCustomBackgroundDesktop"
$githubBranchName = "new_proj"

$RepoUrl = "https://github.com/$githubUsername/$githubRepoName/archive/refs/heads/$githubBranchName.zip"

$localPath = Join-Path $env:APPDATA ".wallpaper_countdown"
$logFile = Join-Path $localPath "install.log"

# download zip and extract it to $env:APPDATA/.wallpaper_countdown
function Write-Log {
    param(
        [string]$Message,
        [string]$Level,
        [string]$LogFile
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Extract-Zip {
    param(
        [string]$ZipPath,
        [string]$Destination
    )

    if(-not (Test-Path $ZipPath)) {
        throw "ZIP not found: $ZipPath"
    }

    if(-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination)
}

function Get-Repo {
    Write-Log "===== INSTALL STARTED =====" "Info" $logFile
    
    Remove-Item "$localPath\*" -Recurse -Force -ErrorAction SilentlyContinue

    $zipPath = Join-Path $env:TEMP "wallpaper.zip"

    Write-Log "Downloading ZIP..." "Info" $logFile
    try {
        Invoke-WebRequest -Uri $RepoUrl -OutFile $zipPath -ErrorAction Stop
    }
    catch {
        Write-Log "Download failed!" "Error" $logFile
        return
    }

    Write-Log "Extracting ZIP..." "Info" $logFile
    Extract-Zip -ZipPath $zipPath -Destination $localPath
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    $innerFolder = Get-ChildItem $localPath -Directory | Select-Object -First 1
    if ($innerFolder) {
        Get-ChildItem $innerFolder.FullName -Force | ForEach-Object {
            Move-Item $_.FullName -Destination $localPath -Force
        }
        Remove-Item $innerFolder.FullName -Recurse -Force
    }
}

# config ScheduledTask to run in $cfg.wallpaper.time that runing the daily_run every day. when its possible, for example, if the copmuter off, when it will on and login. run if computer on battery mode. and so on
function Set-ScheduledTask {
    Import-Module "$env:APPDATA/.wallpaper_countdown/Src/Modules/Config.psm1"
    $configFilePath = "$env:APPDATA/.wallpaper_countdown/Src/config.json"

    Write-Log "Get configuration..." "Info" $logFile

    $cfg = Get-Config $configFilePath $logFile
    
    Write-Log "Creating scheduled task..." "Info" $logFile
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$env:APPDATA\.wallpaper_countdown\Src\daily_run.ps1`"" # -NoExit

    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At $cfg.wallpaper.time
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn

    $setting = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -Compatibility Win8 `
        -Hidden

    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $user -RunLevel Highest

    try {
        Write-Log "try register task" "Info" $logFile
        Register-ScheduledTask -TaskName $cfg.system.taskName -Action $action -Trigger @($dailyTrigger, $logonTrigger) -Settings $setting -Principal $principal -Description "Change wallpaper daily and on logon" | Out-Null
        Write-Log "register task succeed!" "Info" $logFile
    }
    catch {
        Write-Log "Register task failed!" "Error" $logFile
    }
}

New-Item -ItemType Directory -Path $localPath -Force | Out-Null
Write-Log "Start installing..." "Info" $logFile

Get-Repo
Set-ScheduledTask
# run first daily_run
& "$env:APPDATA/.wallpaper_countdown/Src/daily_run.ps1"

#TODO: VBS
