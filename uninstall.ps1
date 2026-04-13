$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$projectRoot\modules\Logging.psm1"
Import-Module "$projectRoot\modules\Cleanup.psm1"

$script:HiddenFolder = Join-Path $env:APPDATA ".wallpaper_cache"
$script:LogFolder = Join-Path $script:HiddenFolder "logs"
$script:LogFile = Join-Path $script:LogFolder "wallpaper_$(Get-Date -Format 'yyyy-MM-dd').log"

Initialize-Logging -AppDir $script:HiddenFolder -LogFolder $script:LogFolder
Write-Log -Message "=== Uninstall started ===" -Level "Info" -LogFile $script:LogFile
Write-Host "Uninstalling..."

Remove-ScheduledTaskSafe -LogFile $script:LogFile
Remove-HiddenFolderSafe -HiddenFolder $script:HiddenFolder -LogFile $script:LogFile

Write-Log -Message "=== Uninstall completed ===" -Level "Info" -LogFile $script:LogFile
Write-Host "Uninstall complete."