function Initialize-Logging {
    param(
        [string]$AppDir,
        [string]$LogFolder
    )

    if (-not [string]::IsNullOrWhiteSpace($AppDir) -and -not (Test-Path $AppDir)) {
        New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($LogFolder) -and -not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$LogFile
    )

    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        return
    }

    try {
        $dir = Split-Path $LogFile -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    }
    catch {
        # logging never breaks execution
    }
}

Export-ModuleMember -Function Initialize-Logging, Write-Log