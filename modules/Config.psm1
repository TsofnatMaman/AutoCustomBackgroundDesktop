function Load-Configuration {
    param([string]$Root, [string]$LogFile)

    $path = Join-Path $Root "config.json"
    Write-Log -Message "Loading configuration from: $path" -Level "Info" -LogFile $LogFile

    if (-not (Test-Path $path)) {
        Write-Log -Message "Configuration file not found at $path" -Level "Error" -LogFile $LogFile
        throw "config.json not found at $path"
    }

    try {
        $config = Get-Content $path -Raw | ConvertFrom-Json
        Write-Log -Message "Configuration loaded successfully" -Level "Info" -LogFile $LogFile
        return $config
    }
    catch {
        Write-Log -Message "Failed to parse configuration: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        throw $_
    }
}

Import-Module "./modules/Logging.psm1"

Export-ModuleMember -Function Load-Configuration