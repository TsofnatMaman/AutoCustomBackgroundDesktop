$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Show-MessageBox {
    param([string]$Message, [string]$Title = "Wallpaper Installer")
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    return [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
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

    $configUrl = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/config.json"
    $tempConfigPath = Join-Path $env:TEMP "wallpaper_config.json"

    Write-Log -Message "Downloading configuration..." -Level "Info" -LogFile $LogFile

    Invoke-WebRequest -Uri $configUrl -OutFile $tempConfigPath -ErrorAction Stop
    return Get-Content $tempConfigPath -Raw | ConvertFrom-Json
}

function Initialize-Logging {
    param($AppDir, $LogFolder)

    if (-not (Test-Path $AppDir)) {
        New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    }

    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }
}

function Create-SafeScheduledTask {
    param(
        [string]$TaskName,
        [string]$LauncherVbs,
        [string]$Time,
        [string]$LogFile
    )

    Write-Log -Message "Creating scheduled task..." -Level "Info" -LogFile $LogFile

    $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$LauncherVbs`""

    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At $Time
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

    Register-ScheduledTask `
        -Action $action `
        -Trigger @($dailyTrigger, $logonTrigger) `
        -Settings $settings `
        -Principal $principal `
        -TaskName $TaskName `
        -Description "Updates wallpaper based on countdown" `
        -Force | Out-Null

    $task = Get-ScheduledTask -TaskName $TaskName
    $task.Settings.StartWhenAvailable = $true
    Set-ScheduledTask -InputObject $task

    Write-Log -Message "Scheduled task created and forced to never miss runs" -Level "Info" -LogFile $LogFile
}

# ---------------- MAIN ----------------

$AppDir = Join-Path $env:APPDATA ".WallpaperProject"
$LogFolder = Join-Path $AppDir "logs"
$LogFile = Join-Path $LogFolder "install.log"

Initialize-Logging -AppDir $AppDir -LogFolder $LogFolder

Write-Log -Message "===== Installation started =====" -Level "Info" -LogFile $LogFile

try {
    $cfg = Load-Configuration -LogFile $LogFile

    $RepoZip = "https://github.com/$($cfg.github.username)/$($cfg.github.repository)/archive/refs/heads/$($cfg.github.branch).zip"
    $TempZip = Join-Path $env:TEMP "wallpaper.zip"

    if (Test-Path $AppDir) {
        Remove-Item $AppDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null

    Invoke-WebRequest -Uri $RepoZip -OutFile $TempZip -ErrorAction Stop

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $AppDir)

    Remove-Item $TempZip -Force -ErrorAction SilentlyContinue

    $projectFolder = Get-ChildItem $AppDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    $main = Join-Path $projectFolder.FullName "main.ps1"

    if (-not (Test-Path $main)) {
        throw "main.ps1 not found"
    }

    $launcherVbs = Join-Path $projectFolder.FullName "run-main-hidden.vbs"

    $vbs = @"
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$main""", 0, False
"@

    Set-Content -Path $launcherVbs -Value $vbs -Encoding ASCII

    Create-SafeScheduledTask `
        -TaskName $cfg.app.taskName `
        -LauncherVbs $launcherVbs `
        -Time $cfg.wallpaper.time `
        -LogFile $LogFile

    Start-Process wscript.exe -ArgumentList "`"$launcherVbs`"" -WindowStyle Hidden | Out-Null

    Write-Log -Message "===== Installation completed =====" -Level "Info" -LogFile $LogFile
    Show-MessageBox -Message "✓ ההתקנה הושלמה בהצלחה" -Title "Wallpaper Installer"
}
catch {
    Write-Log -Message $_.Exception.Message -Level "Error" -LogFile $LogFile
    Show-MessageBox -Message "✗ התקנה נכשלה: $($_.Exception.Message)" -Title "Error"
    exit 1
}