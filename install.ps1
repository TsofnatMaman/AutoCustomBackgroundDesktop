$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ---------------- UI ----------------
function Show-MessageBox {
    param([string]$Message, [string]$Title = "Wallpaper Installer")

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

# ---------------- LOGGING ----------------
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$LogFile
    )

    if (-not $LogFile) { return }

    $dir = Split-Path $LogFile -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# ---------------- CONFIG ----------------
function Load-Configuration {
    param([string]$LogFile)

    $url = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/config.json"
    $tmp = Join-Path $env:TEMP "config.json"

    Invoke-WebRequest -Uri $url -OutFile $tmp -ErrorAction Stop
    return Get-Content $tmp -Raw | ConvertFrom-Json
}

# ---------------- ZIP EXTRACT (FIXED) ----------------
function Extract-Zip {
    param(
        [string]$ZipPath,
        [string]$Destination
    )

    if (-not (Test-Path $ZipPath)) {
        throw "ZIP not found: $ZipPath"
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination)
}

# ---------------- INIT ----------------
$AppDir = Join-Path $env:APPDATA ".WallpaperProject"
$LogDir = Join-Path $AppDir "logs"
$LogFile = Join-Path $LogDir "install.log"

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

Write-Log "===== INSTALL STARTED =====" "Info" $LogFile

try {
    # ---------------- LOAD CONFIG ----------------
    $cfg = Load-Configuration -LogFile $LogFile

    $user = $cfg.github.username
    $repo = $cfg.github.repository
    $branch = $cfg.github.branch

    $zipUrl = "https://github.com/$user/$repo/archive/refs/heads/$branch.zip"
    $zipPath = Join-Path $env:TEMP "wallpaper.zip"

    # ---------------- CLEAN OLD ----------------
    if (Test-Path $AppDir) {
        Remove-Item $AppDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null

    # ---------------- DOWNLOAD ZIP ----------------
    Write-Log "Downloading ZIP..." "Info" $LogFile
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop

    # ---------------- EXTRACT ZIP ----------------
    Write-Log "Extracting ZIP..." "Info" $LogFile
    Extract-Zip -ZipPath $zipPath -Destination $AppDir

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    # ---------------- FIND PROJECT ROOT ----------------
    $project = Get-ChildItem $AppDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    $main = Join-Path $project.FullName "main.ps1"

    if (-not (Test-Path $main)) {
        throw "main.ps1 missing after extraction"
    }

    # ---------------- CREATE TASK ----------------
    Write-Log "Creating scheduled task..." "Info" $LogFile

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$main`""

    $trigger1 = New-ScheduledTaskTrigger -AtLogOn
    $trigger2 = New-ScheduledTaskTrigger -Daily -At $cfg.wallpaper.time

    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $cfg.app.taskName `
        -Action $action `
        -Trigger @($trigger1, $trigger2) `
        -Settings $settings `
        -Principal $principal `
        -Force | Out-Null

    Write-Log "INSTALL COMPLETE" "Info" $LogFile

    Show-MessageBox "Installation completed successfully"
}
catch {
    Write-Log $_.Exception.Message "Error" $LogFile
    Show-MessageBox "Installation failed: $($_.Exception.Message)"
    exit 1
}