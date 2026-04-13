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

    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $logMessage

    Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Initialize-Logging, Write-Log