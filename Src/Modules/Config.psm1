Import-Module "$PSScriptRoot/Logging.psm1"
Import-Module "$PSScriptRoot/Downloads.psm1"

function Get-Config {
    param(
        [string]$ConfigFilePath,
        [string]$LogFile = $null
    )

    if([string]::IsNullOrWhiteSpace($ConfigFilePath) -or -not (Test-Path $ConfigFilePath)) {
        Write-Log -Message "Config File Path ($ConfigFilePath) not provided or does not exist." -Level "Warning" -LogFile $LogFile
        throw "Config File Path ($ConfigFilePath) not provided or does not exist."
    }

    try {
        $config = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json
        Write-Log -Message "Configuration loaded successfully" -Level "Info" -LogFile $LogFile
        return $config
    }
    catch {
        Write-Log -Message "Failed to parse configuration: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        throw $_
    }
}

Export-ModuleMember -Function Get-Config