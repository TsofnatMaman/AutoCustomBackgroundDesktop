$ErrorActionPreference = "Stop"

$AppDir = Join-Path $env:APPDATA ".WallpaperProject"
$TaskName = "ChangeWallpaperEveryDay"

$u = $cfg.github.username
$r = $cfg.github.repository
$b = $cfg.github.branch

$RepoZip = "https://github.com/$u/$r/archive/refs/heads/$b.zip"
$TempZip = Join-Path $env:TEMP "wallpaper.zip"

Write-Host "Downloading latest version from Git..."

# ניקוי ישן
if (Test-Path $AppDir) {
    Remove-Item $AppDir -Recurse -Force
}

# יצירת תיקייה
New-Item -ItemType Directory -Path $AppDir -Force | Out-Null

# הורדה
Invoke-WebRequest -Uri $RepoZip -OutFile $TempZip

# חילוץ ZIP (בלי תלות במודולים)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $AppDir)

# מחיקת ZIP
Remove-Item $TempZip -Force -ErrorAction SilentlyContinue

# GitHub יוצר תיקייה פנימית → מאתרים אותה
$projectFolder = Get-ChildItem $AppDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1

if (-not $projectFolder) {
    throw "Extraction failed"
}

# נתיב ל-main.ps1 האמיתי
$main = Join-Path $projectFolder.FullName "main.ps1"

if (-not (Test-Path $main)) {
    throw "main.ps1 not found. Check repo structure."
}

# יצירת Scheduled Task נכון (USER SESSION ולא ADMIN)
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$main`""

$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Force

# הרצה ראשונית (לא חובה אבל טוב לבדיקה)
Start-Process powershell.exe "-File `"$main`""

Write-Host "Installed from Git successfully."