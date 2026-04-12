# Requires: Windows PowerShell 5+ (or PowerShell 7 with Windows Compatibility)
# Purpose: Download a fresh base image daily, render a countdown text on it,
#          set it as the desktop wallpaper, and schedule daily + logon updates.

# --- self-elevate (silent) once if not admin ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        $vbsPath = Join-Path $env:TEMP "elevate_run.vbs"
        $escaped = $PSCommandPath.Replace("""","""""")  # escape quotes for VBS
        $vbs = @"
Set sh = CreateObject("Shell.Application")
' Run elevated (UAC), hidden window (0)
sh.ShellExecute "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$escaped""", "", "runas", 0
"@
        Set-Content -Path $vbsPath -Value $vbs -Encoding ASCII
        Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`""
    } catch { }
    exit
}
# --- end self-elevate ---

Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-ScriptPath {
    if ($PSCommandPath) { return $PSCommandPath }
    return $MyInvocation.MyCommand.Path
}

function Initialize-Directory([string]$Path) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

function Get-BaseImage([string]$RemoteImageUrl, [string]$BaseImagePath) {
    Write-Host "Downloading base image..."
    $cacheBust  = [Uri]::EscapeDataString((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffffK"))
    $downloadOk = $true
    try {
        $u = $RemoteImageUrl -replace '[\u200E\u200F\u202A-\u202E]', ''  # remove bidi marks
        $u = $u.Trim()
        if (-not [Uri]::IsWellFormedUriString($u, [UriKind]::Absolute)) { throw "Bad remoteImageUrl: '$u'" }

        if ($u -match '\?') { $joinChar = '&' } else { $joinChar = '?' }
        $downloadUri = "$u$joinChar" + "ts=$cacheBust"

        Write-Host "remoteImageUrl=<$u>"
        Write-Host "downloadUri=<$downloadUri>"

        Invoke-WebRequest -Uri ([Uri]$downloadUri) -OutFile $BaseImagePath `
            -Headers @{ 'Cache-Control'='no-cache'; 'Pragma'='no-cache' } `
            -UseBasicParsing -ErrorAction Stop
        Write-Host "Download success -> $BaseImagePath"
    }
    catch {
        $downloadOk = $false
        Write-Host "Download failed: $($_.Exception.Message)"
        if (-not (Test-Path $BaseImagePath)) {
            Write-Host "No local fallback image. Exiting."
            exit
        } else {
            Write-Host "Using existing local image as fallback."
        }
    }
    return $downloadOk
}

function Export-CountdownImage(
    [string]$BaseImagePath,
    [string]$FinalImagePath,
    [string]$Text
) {
    $bytes = [System.IO.File]::ReadAllBytes($BaseImagePath)
    $ms    = New-Object System.IO.MemoryStream(,$bytes)
    $image = [System.Drawing.Image]::FromStream($ms)

    $graphics = [System.Drawing.Graphics]::FromImage($image)
    $graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    try { $fontFamily = New-Object System.Drawing.FontFamily("David") } catch { $fontFamily = New-Object System.Drawing.FontFamily("Arial") }
    $fontSize = 72
    $font     = New-Object System.Drawing.Font($fontFamily, $fontSize, [System.Drawing.FontStyle]::Bold)

    $brushText       = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $brushShadow     = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 0, 0, 0))
    $backgroundBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 0, 0, 0))

    $stringFormat = New-Object System.Drawing.StringFormat
    $stringFormat.Alignment     = [System.Drawing.StringAlignment]::Center
    $stringFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    # $stringFormat.FormatFlags   = [System.Drawing.StringFormatFlags]::DirectionRightToLeft

    $textSize = $graphics.MeasureString($Text, $font)

    # Force numeric types to [single] for PS5 interop
    $cx = [single]($image.Width  / 2.0)
    $cy = [single]($image.Height / 2.0)
    $halfTextW = [single]($textSize.Width  / 2.0)
    $halfTextH = [single]($textSize.Height / 2.0)

    $padding       = [single]30
    $shadowOffsetX = [single]4
    $shadowOffsetY = [single]4

    $rectX      = [single]($cx - $halfTextW - $padding)
    $rectY      = [single]($cy - $halfTextH - $padding)
    $rectWidth  = [single]($textSize.Width  + ($padding * 2))
    $rectHeight = [single]($textSize.Height + ($padding * 2))
    [void]$graphics.FillRectangle($backgroundBrush, $rectX, $rectY, $rectWidth, $rectHeight)

    $shadowPoint = New-Object System.Drawing.PointF(([single]($cx + $shadowOffsetX)), ([single]($cy + $shadowOffsetY)))
    [void]$graphics.DrawString($Text, $font, $brushShadow, $shadowPoint, $stringFormat)

    $point = New-Object System.Drawing.PointF($cx, $cy)
    [void]$graphics.DrawString($Text, $font, $brushText, $point, $stringFormat)

    $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
    $qualityEncoder = [System.Drawing.Imaging.Encoder]::Quality
    $encParam       = New-Object System.Drawing.Imaging.EncoderParameter($qualityEncoder, 95L)
    $encParams.Param[0] = $encParam

    Initialize-Directory $FinalImagePath
    $image.Save($FinalImagePath, $jpegCodec, $encParams)

    $graphics.Dispose()
    $font.Dispose()
    $brushText.Dispose()
    $brushShadow.Dispose()
    $backgroundBrush.Dispose()
    $stringFormat.Dispose()
    $image.Dispose()
    $ms.Dispose()
}

function Set-WallpaperFromPath([string]$FinalImagePath) {
    if (-not ("Wallpaper" -as [type])) {
        Add-Type -TypeDefinition @"
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@
    }
    [Wallpaper]::SystemParametersInfo(20, 0, $FinalImagePath, 3) | Out-Null
}

function Register-DailyTask(
    [string]$TaskName,
    [string]$VbsPath, 
    [string]$DailyTime
) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At $DailyTime
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn

    $settings = New-ScheduledTaskSettingsSet `
      -StartWhenAvailable `
      -AllowStartIfOnBatteries `
      -DontStopIfGoingOnBatteries `
      -MultipleInstances IgnoreNew `
      -Compatibility Win8 `
      -Hidden

    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $user -RunLevel Highest

    $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$VbsPath`""

    if (-not $existing) {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($dailyTrigger, $logonTrigger) -Settings $settings -Principal $principal -Description "Change wallpaper daily and on logon (silent)" | Out-Null
        Write-Host "Scheduled task created (silent via VBS)."
    } else {
        Set-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($dailyTrigger, $logonTrigger) -Settings $settings -Principal $principal
        Write-Host "Scheduled task updated (silent via VBS)."
    }
}

function Set-VbsLauncher([string]$ScriptPath, [string]$VbsPath) {
    Initialize-Directory $VbsPath
    $vbs = @"
Set sh = CreateObject("Wscript.Shell")
' 0 = hidden, False = do not wait
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File ""$ScriptPath""", 0, False
"@
    Set-Content -Path $VbsPath -Value $vbs -Encoding ASCII
}

# --- Script path fallback (when run manually) ---
$scriptPath = Get-ScriptPath

# --- Remote sources (for your reference; not used at runtime) ---
# $remoteScriptUrl = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/main/script1.ps1"
$remoteImageUrl  = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/main/backgrounds/1.jpg"

# --- Target date / countdown ---
$targetDay  = Get-Date "2026-04-20"
$today      = Get-Date
$currentDay = ($targetDay - $today).Days
if ($currentDay -le 0) { exit }  # stop when the date has passed

# --- Local paths ---
$baseImagePath  = "$env:APPDATA\Microsoft\Windows\1.jpg"                 # downloaded image (overwritten daily)
$finalImagePath = "$env:APPDATA\Microsoft\Windows\wallpaper_current.jpg" # rendered image used by Windows

Initialize-Directory $baseImagePath
Initialize-Directory $finalImagePath

# Text to render (Hebrew)
$text = "...עוד $currentDay ימים"

# ------------ Main flow ------------
$downloadOk = Get-BaseImage -RemoteImageUrl $remoteImageUrl -BaseImagePath $baseImagePath
Export-CountdownImage -BaseImagePath $baseImagePath -FinalImagePath $finalImagePath -Text $text
Set-WallpaperFromPath -FinalImagePath $finalImagePath
Write-Host "Wallpaper update success: '$text' (downloadOk=$downloadOk)"

# --- Scheduled Task: Daily 00:30 + AtLogOn, Highest Privileges ---
$taskName = "ChangeWallpaperEveryDay"
$dailyTime = "00:30"

$vbsPath = "$env:APPDATA\Microsoft\Windows\run_wallpaper_silent.vbs"
Set-VbsLauncher -ScriptPath $scriptPath -VbsPath $vbsPath
Register-DailyTask -TaskName $taskName -VbsPath $vbsPath -DailyTime $dailyTime

Write-Host "Done. Final image: $finalImagePath"
