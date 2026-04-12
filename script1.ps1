# Requires: Windows PowerShell 5+
# Purpose: Dynamic Wallpaper Updater with Cache Busting

# --- Hidden Folder Setup ---
$script:HiddenFolder = Join-Path $env:APPDATA ".wallpaper_cache"
$script:LogFolder = Join-Path $script:HiddenFolder "logs"
$script:LogFile = Join-Path $script:LogFolder "wallpaper_$(Get-Date -Format 'yyyy-MM-dd').log"

function Initialize-Logging {
    if (-not (Test-Path $script:HiddenFolder)) {
        New-Item -ItemType Directory -Path $script:HiddenFolder -Force | Out-Null
        (Get-Item $script:HiddenFolder -Force).Attributes = "Hidden"
    }
    if (-not (Test-Path $script:LogFolder)) {
        New-Item -ItemType Directory -Path $script:LogFolder -Force | Out-Null
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $logMessage = "[(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
}

# --- Self-Elevate ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $vbsPath = Join-Path $env:TEMP "elevate_run.vbs"
    $escaped = $PSCommandPath.Replace("""","""""")
    @"
Set sh = CreateObject("Shell.Application")
sh.ShellExecute "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$escaped""", "", "runas", 0
"@ | Set-Content -Path $vbsPath -Encoding ASCII
    Start-Process "wscript.exe" "`"$vbsPath`""
    exit
}

Initialize-Logging
Write-Log "Script started"

Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Load Configuration with Cache Busting ---
function Load-Configuration {
    $baseUrl = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/config.json"
    $configPath = Join-Path $script:HiddenFolder "config.json"
    $configURL = "$baseUrl?ts=$(Get-Date -UFormat %s)"
    
    try {
        Write-Log "Downloading fresh config..."
        $response = Invoke-WebRequest -Uri $configURL -UseBasicParsing -ErrorAction Stop
        $jsonText = if ($response.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($response.Content) } else { $response.Content.ToString() }
        
        if ($jsonText.StartsWith([char]0xFEFF)) { $jsonText = $jsonText.Substring(1) }
        
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($configPath, $jsonText, $utf8)
        return $jsonText | ConvertFrom-Json
    }
    catch {
        Write-Log "Config download failed, using local." -Level Warning
        return Get-Content $configPath -Raw | ConvertFrom-Json
    }
}

$script:Config = Load-Configuration

# --- Image Management ---
function Get-BaseImage([string]$RemoteImageUrl, [string]$BaseImagePath) {
    if (Test-Path $BaseImagePath) { Remove-Item $BaseImagePath -Force }
    
    $cacheBust = [Uri]::EscapeDataString((Get-Date).ToString("yyyyMMddHHmmss"))
    $u = ($RemoteImageUrl -replace '[\u200E\u200F\u202A-\u202E]', '').Trim()
    $downloadUri = if ($u -match '\?') { "$u&ts=$cacheBust" } else { "$u?ts=$cacheBust" }

    try {
        Invoke-WebRequest -Uri $downloadUri -OutFile $BaseImagePath -UseBasicParsing `
            -Headers @{ 'Cache-Control'='no-cache'; 'Pragma'='no-cache' } -ErrorAction Stop
        Write-Log "New image downloaded successfully."
        return $true
    }
    catch {
        Write-Log "Failed to download image: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Export-CountdownImage([string]$BaseImagePath, [string]$FinalImagePath, [string]$Text) {
    $bytes = [System.IO.File]::ReadAllBytes($BaseImagePath)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $image = [System.Drawing.Image]::FromStream($ms)
    $graphics = [System.Drawing.Graphics]::FromImage($image)
    
    $graphics.SmoothingMode = "HighQuality"
    $graphics.TextRenderingHint = "ClearTypeGridFit"

    $fontFamily = try { New-Object System.Drawing.FontFamily("David") } catch { New-Object System.Drawing.FontFamily("Arial") }
    $font = New-Object System.Drawing.Font($fontFamily, 72, [System.Drawing.FontStyle]::Bold)
    
    $brushText = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $backgroundBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 0, 0, 0))
    $format = New-Object System.Drawing.StringFormat -Property @{ Alignment = "Center"; LineAlignment = "Center" }

    $textSize = $graphics.MeasureString($Text, $font)
    $rect = New-Object System.Drawing.RectangleF(
        ([single]($image.Width/2 - $textSize.Width/2 - 20)), 
        ([single]($image.Height/2 - $textSize.Height/2 - 20)), 
        ([single]($textSize.Width + 40)), 
        ([single]($textSize.Height + 40))
    )

    $graphics.FillRectangle($backgroundBrush, $rect)
    $graphics.DrawString($Text, $font, $brushText, (New-Object System.Drawing.PointF($image.Width/2, $image.Height/2)), $format)

    $image.Save($FinalImagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    
    $graphics.Dispose(); $image.Dispose(); $ms.Dispose()
}

function Set-Wallpaper([string]$Path) {
    $code = @"
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@
    if (-not ("Wallpaper" -as [type])) { Add-Type -TypeDefinition $code }
    [Wallpaper]::SystemParametersInfo(20, 0, $Path, 3) | Out-Null
}

# --- Execution ---
$remoteImageUrl = "https://raw.githubusercontent.com/$($script:Config.github.username)/$($script:Config.github.repository)/$($script:Config.github.branch)/$($script:Config.github.imagePath)"
$baseImg = Join-Path $script:HiddenFolder "base_image.jpg"
$finalImg = Join-Path $script:HiddenFolder "wallpaper_current.jpg"

if (Get-BaseImage -RemoteImageUrl $remoteImageUrl -BaseImagePath $baseImg) {
    $days = ((Get-Date $script:Config.wallpaper.targetDate) - (Get-Date)).Days
    $text = $script:Config.wallpaper.text.Replace('{days}', $days)
    
    Export-CountdownImage -BaseImagePath $baseImg -FinalImagePath $finalImg -Text $text
    Set-Wallpaper -Path $finalImg
    Write-Log "Wallpaper updated to: $text"
}

Write-Log "Script finished."