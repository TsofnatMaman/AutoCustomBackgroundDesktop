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

function Get-RemoteConfigUrl {
    param($cfg)

    if (-not $cfg -or -not $cfg.github) {
        throw "Missing github settings in configuration."
    }

    $username = $cfg.github.username
    $repository = $cfg.github.repository
    $branch = $cfg.github.branch
    $configPath = if ($cfg.github.configPath) { $cfg.github.configPath } else { "config.json" }

    if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($repository) -or [string]::IsNullOrWhiteSpace($branch)) {
        throw "github.username/repository/branch must be set in config.json"
    }

    return "https://raw.githubusercontent.com/$username/$repository/$branch/$configPath"
}

function Update-ConfigurationFromRemote {
    param(
        [string]$Root,
        $cfg,
        [string]$LogFile
    )

    $path = Join-Path $Root "config.json"

    try {
        $url = Get-RemoteConfigUrl -cfg $cfg
        Write-Log -Message "Downloading latest configuration from: $url" -Level "Info" -LogFile $LogFile

        Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop

        Write-Log -Message "Configuration refreshed successfully at: $path" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Configuration refresh failed: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile
        return $false
    }
}

Import-Module (Join-Path $PSScriptRoot "Logging.psm1")

Export-ModuleMember -Function Load-Configuration, Get-RemoteConfigUrl, Update-ConfigurationFromRemote
