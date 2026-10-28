$githubUsername = "TsofnatMaman"
$githubRepoName = "AutoCustomBackgroundDesktop"
$githubBranchName = "main"

$RepoUrl = "https://github.com/$githubUsername/$githubRepoName/archive/refs/heads/$githubBranchName.zip"

# An elevated installer can run as a *different* administrator account.
# Resolve the desktop user from explorer.exe in this Windows session, not the
# elevated process token. Never silently pick a user if the session is ambiguous.
function Get-InstallTarget {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $sid = $identity.User.Value

    if ($elevated) {
        $sessionId = (Get-Process -Id $PID).SessionId
        $explorers = @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction Stop |
            Where-Object { $_.SessionId -eq $sessionId })
        $candidates = @($explorers | ForEach-Object {
            $owner = Invoke-CimMethod -InputObject $_ -MethodName GetOwnerSid -ErrorAction SilentlyContinue
            if ($owner.ReturnValue -eq 0 -and $owner.Sid -match '^S-1-5-21-') { $owner.Sid }
        } | Sort-Object -Unique)
        if ($candidates.Count -ne 1) {
            throw "Could not uniquely identify the desktop user in session $sessionId (found $($candidates.Count)). Sign in as the target user and run the installer from that desktop."
        }
        $sid = $candidates[0]
    }

    $profileKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
    $profile = (Get-ItemProperty -LiteralPath $profileKey -ErrorAction Stop).ProfileImagePath
    $profile = [Environment]::ExpandEnvironmentVariables($profile)
    if (-not (Test-Path -LiteralPath $profile -PathType Container)) {
        throw "Target profile directory does not exist: $profile"
    }
    $account = ([Security.Principal.SecurityIdentifier]$sid).Translate([Security.Principal.NTAccount]).Value
    return [PSCustomObject]@{ Sid = $sid; Account = $account; Profile = $profile; Elevated = $elevated }
}

Add-Type -AssemblyName System.Windows.Forms
try {
    $target = Get-InstallTarget
}
catch {
    $message = "Cannot determine target Windows user: $($_.Exception.Message)"
    Write-Host $message
    [System.Windows.Forms.MessageBox]::Show($message, "Wallpaper Installer") | Out-Null
    exit 1
}
$localPath = Join-Path $target.Profile "AppData\Roaming\.wallpaper_countdown"
$logDir = Join-Path $target.Profile "AppData\Local\WallpaperCountdown\logs"
$logFile = Join-Path $logDir "install.log"
New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null

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
    Import-Module (Join-Path $localPath "Src\Modules\Config.psm1") -WarningAction SilentlyContinue
    $configFilePath = Join-Path $localPath "Src\config.json"

    Write-Log "Get configuration..." "Info" $logFile

    $cfg = Get-Config $configFilePath $logFile
    
    Write-Log "Creating scheduled task..." "Info" $logFile
    # $action = New-ScheduledTaskAction `
    #     -Execute "powershell.exe" `
    #     -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$env:APPDATA\.wallpaper_countdown\Src\daily_run.ps1`"" # -NoExit

    $action = New-ScheduledTaskAction `
        -Execute "wscript.exe" `
        -Argument "`"$(Join-Path $localPath 'Src\run_hidden.vbs')`""

    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At $cfg.wallpaper.time
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn

    $setting = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -Compatibility Win8 `
        -Hidden

    $user = $target.Account
    $sid = $target.Sid
    $taskName = "$($cfg.system.taskName)-$sid"
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

    try {
        Write-Log "try register task" "Info" $logFile
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($dailyTrigger, $logonTrigger) -Settings $setting -Principal $principal -Description "Change wallpaper daily and on logon" -ErrorAction Stop | Out-Null
        $registered = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $registeredUserId = $registered.Principal.UserId
        if ($registeredUserId -match "^S-1-") {
            $registeredSid = $registeredUserId
        }
        else {
            $registeredSid = ([Security.Principal.NTAccount]$registeredUserId).Translate([Security.Principal.SecurityIdentifier]).Value
        }
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
        Write-Log "Register task failed: $($_.Exception.Message). If access is denied, run the installer as administrator from the target user desktop." "Error" $logFile
        throw
    }
}

Add-Type -AssemblyName System.Windows.Forms
New-Item -ItemType Directory -Path $localPath -Force | Out-Null
Write-Log "Start installing for $($target.Account) ($($target.Profile)); elevated=$($target.Elevated)" "Info" $logFile

try {
    Get-Repo
    # Elevated-created files must be writable by the limited interactive task.
    if ($target.Elevated) {
        $acl = Get-Acl -LiteralPath $localPath -ErrorAction Stop
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $target.Account, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $localPath -AclObject $acl -ErrorAction Stop
    }
    Set-ScheduledTask
    Write-Log "Running initial wallpaper update as $($target.Account) via scheduled task..." "Info" $logFile
    $taskName = "$((Get-Content (Join-Path $localPath 'Src\config.json') -Raw | ConvertFrom-Json).system.taskName)-$($target.Sid)"
    $before = (Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop).LastRunTime
    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $deadline = (Get-Date).AddMinutes(3)
    $completed = $false
    do {
        Start-Sleep -Seconds 2
        $status = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        if ($status.LastRunTime -gt $before -and $status.LastTaskResult -eq 0) {
            $completed = $true
            break
        }
        if ($status.LastRunTime -gt $before -and $status.LastTaskResult -notin @(0,267009)) {
            throw "Initial scheduled run returned code $($status.LastTaskResult)"
        }
    } while ((Get-Date) -lt $deadline)
    if (-not $completed) { throw "Initial task run did not complete successfully within 3 minutes. Check Task Scheduler and user cache logs." }
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
