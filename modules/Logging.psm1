function Initialize-Logging {
    param($AppDir, $LogFolder)

    if (-not (Test-Path $AppDir)) {
        New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    }

    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$LogFile
    )

    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

Export-ModuleMember -Function Initialize-Logging, Write-Log