$githubUsername = "TsofnatMaman"
$githubRepoName = "AutoCustomBackgroundDesktop"
$githubBranchName = "shira-wedding"

$RepoUrl = "https://github.com/$githubUsername/$githubRepoName/archive/refs/heads/$githubBranchName.zip"

# This is a per-user installer. Elevation (especially with another account\'s UAC
# credentials) changes APPDATA and WindowsIdentity to the administrator account.
# Abort before writing files or creating tasks in the wrong profile.
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $message = "This installer must run WITHOUT administrator elevation. Sign in as the intended Windows user and launch install.exe normally (not Run as administrator). No changes were made."
    Write-Host $message
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($message, "Wallpaper Installer", "OK", "Warning") | Out-Null
    exit 1
}

$localPath = Join-Path $env:APPDATA ".wallpaper_countdown"
$logDir = Join-Path $env:LOCALAPPDATA "WallpaperCountdown\logs"
$logFile = Join-Path $logDir "install.log"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

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

    $zipPath = Join-Path $env:TEMP "wallpaper.zip"
    $stagingPath = Join-Path $env:TEMP ("wallpaper_extract_" + [guid]::NewGuid().ToString())

    Write-Log "Downloading ZIP..." "Info" $logFile
    try {
        Invoke-WebRequest -Uri $RepoUrl -OutFile $zipPath -ErrorAction Stop
    }
    catch {
        Write-Log "Download failed!" "Error" $logFile
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
        throw "Download failed!"
    }

    Write-Log "Extracting ZIP..." "Info" $logFile
    try {
        Extract-Zip -ZipPath $zipPath -Destination $stagingPath
    }
    catch {
        Write-Log "Extraction failed!" "Error" $logFile
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
        throw "Extraction failed!"
    }

    $innerFolder = Get-ChildItem $stagingPath -Directory | Select-Object -First 1
    if ($innerFolder) {
        try {
            Remove-Item "$localPath\*" -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Log "Failed to clear existing installation!" "Error" $logFile
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
            throw "Failed to clear existing installation!"
        }

        Get-ChildItem $innerFolder.FullName -Force | ForEach-Object {
            Move-Item $_.FullName -Destination $localPath -Force
        }
        Remove-Item $innerFolder.FullName -Recurse -Force
    }

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
}

# config ScheduledTask to run in $cfg.wallpaper.time that runs the daily_run every day. when possible, for example, if the computer is off, it will run when it turns on and the user logs in. also runs on battery mode.
function Set-ScheduledTask {
    Import-Module "$env:APPDATA/.wallpaper_countdown/Src/Modules/Config.psm1" -WarningAction SilentlyContinue
    $configFilePath = "$env:APPDATA/.wallpaper_countdown/Src/config.json"

    Write-Log "Get configuration..." "Info" $logFile

    $cfg = Get-Config $configFilePath $logFile
    
    Write-Log "Creating scheduled task..." "Info" $logFile
    # $action = New-ScheduledTaskAction `
    #     -Execute "powershell.exe" `
    #     -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$env:APPDATA\.wallpaper_countdown\Src\daily_run.ps1`"" # -NoExit

    $action = New-ScheduledTaskAction `
        -Execute "wscript.exe" `
        -Argument "`"$env:APPDATA\.wallpaper_countdown\Src\run_hidden.vbs`""

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
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $taskName = "$($cfg.system.taskName)-$sid"
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

    try {
        Write-Log "try register task" "Info" $logFile
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($dailyTrigger, $logonTrigger) -Settings $setting -Principal $principal -Description "Change wallpaper daily and on logon" -ErrorAction Stop | Out-Null
        $registered = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $registeredSid = ([Security.Principal.NTAccount]$registered.Principal.UserId).Translate([Security.Principal.SecurityIdentifier]).Value
        if ($registeredSid -ne $sid) {
            throw "Task owner mismatch: expected $sid but found $registeredSid"
        }
        if ($registered.State -eq "Disabled" -or $registered.Actions.Count -lt 1) {
            throw "Task is disabled or has no action: $taskName"
        }
        Write-Log "Scheduled task verified: $taskName; SID=$registeredSid; state=$($registered.State); script=$($action.Arguments)" "Info" $logFile
        Write-Log "register task succeed!" "Info" $logFile
    }
    catch {
        Write-Log "Register task failed: $($_.Exception.Message)" "Error" $logFile
        throw
    }
}

Add-Type -AssemblyName System.Windows.Forms
New-Item -ItemType Directory -Path $localPath -Force | Out-Null
Write-Log "Start installing for $([Security.Principal.WindowsIdentity]::GetCurrent().Name) ($env:APPDATA)" "Info" $logFile

try {
    Get-Repo
    Set-ScheduledTask
    Write-Log "Running initial wallpaper update..." "Info" $logFile
    $scriptPath = Join-Path $localPath "Src\daily_run.ps1"
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1 |
        ForEach-Object { Write-Log "$_" "Info" $logFile }
    if ($LASTEXITCODE -ne 0) { throw "Initial wallpaper update failed (exit code $LASTEXITCODE). Check cache logs." }
    Write-Log "Install success!" "Info" $logFile
    Write-Host "Install success! Log: $logFile"
    [System.Windows.Forms.MessageBox]::Show("Installation completed successfully.`nLog: $logFile", "Wallpaper Installer") | Out-Null
}
catch {
    $message = "Install failed: $($_.Exception.Message)`nLog: $logFile"
    Write-Log $message "Error" $logFile
    Write-Host $message
    [System.Windows.Forms.MessageBox]::Show($message, "Wallpaper Installer") | Out-Null
    exit 1
}
