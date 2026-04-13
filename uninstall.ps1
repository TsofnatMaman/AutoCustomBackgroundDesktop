$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$projectRoot\modules\Logging.psm1"
Import-Module "$projectRoot\modules\Cleanup.psm1"

$script:HiddenFolder = Join-Path $env:APPDATA ".wallpaper_cache"
$script:LogFolder = Join-Path $script:HiddenFolder "logs"
$script:LogFile = Join-Path $script:LogFolder "wallpaper_$(Get-Date -Format 'yyyy-MM-dd').log"

Initialize-Logging
Write-Host "Uninstalling..."

Remove-ScheduledTaskSafe
Remove-HiddenFolderSafe -HiddenFolder $script:HiddenFolder

Write-Host "Uninstall complete."