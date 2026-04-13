$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$projectRoot\modules\Logging.psm1"
Import-Module "$projectRoot\modules\Cleanup.psm1"

$logFolder = Join-Path $env:APPDATA ".wallpaper_cache\logs"
$logFile = Join-Path $logFolder "uninstall_$(Get-Date -Format 'yyyy-MM-dd').log"

Initialize-Logging -AppDir $env:APPDATA ".wallpaper_cache" -LogFolder $logFolder

Uninstall-Project -LogFile $logFile