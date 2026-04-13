[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:HiddenFolder = Join-Path $env:APPDATA ".wallpaper_cache"
$script:LogFolder = Join-Path $script:HiddenFolder "logs"
$script:LogFile = Join-Path $script:LogFolder "wallpaper_$(Get-Date -Format 'yyyy-MM-dd').log"

Import-Module "$PSScriptRoot\modules\Logging.psm1"
Import-Module "$PSScriptRoot\modules\Config.psm1"
Import-Module "$PSScriptRoot\modules\Image.psm1"
Import-Module "$PSScriptRoot\modules\System.psm1"
Import-Module "$PSScriptRoot\modules\Cleanup.psm1"

Ensure-Admin

Initialize-Logging
Write-Log "Script execution started."

Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:Config = Load-Configuration -HiddenFolder $script:HiddenFolder

$targetDate = Get-Date $script:Config.wallpaper.targetDate
$daysRemaining = ($targetDate - (Get-Date)).Days

if ($daysRemaining -lt 0) {
    Uninstall-Project -HiddenFolder $script:HiddenFolder
}

$uName = $script:Config.github.username.Trim()
$uRepo = $script:Config.github.repository.Trim()
$uBranch = $script:Config.github.branch.Trim()
$uPath = $script:Config.github.imagePath.Trim()

$remoteImageUrl = "https://raw.githubusercontent.com/$uName/$uRepo/$uBranch/$uPath"
$baseImg = Join-Path $script:HiddenFolder "base_image.jpg"
$finalImg = Join-Path $script:HiddenFolder "wallpaper_$(Get-Date -Format 'HHmm').jpg"

Get-ChildItem $script:HiddenFolder -Filter "wallpaper_*.jpg" | Remove-Item -Force -ErrorAction SilentlyContinue

if (Get-BaseImage -RemoteImageUrl $remoteImageUrl -BaseImagePath $baseImg) {
    $text = $script:Config.wallpaper.text.Replace('{days}', $daysRemaining)
    Export-CountdownImage -BaseImagePath $baseImg -FinalImagePath $finalImg -Text $text
    Set-Wallpaper -Path $finalImg
    Write-Log "Wallpaper successfully updated. Days remaining: $daysRemaining"
}

Write-Log "Script execution finished."