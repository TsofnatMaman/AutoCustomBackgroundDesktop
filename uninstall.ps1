$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module "$projectRoot\modules\Logging.psm1"
Import-Module "$projectRoot\modules\Cleanup.psm1"

$baseDir = Join-Path $env:TEMP ".wallpaper_cache"

$logFolder = Join-Path $baseDir "logs"
$logFile = Join-Path $logFolder "uninstall_$(Get-Date -Format 'yyyy-MM-dd').log"

Initialize-Logging -AppDir $baseDir -LogFolder $logFolder

Uninstall-Project -LogFile $logFile