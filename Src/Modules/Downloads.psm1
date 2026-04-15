Import-Module "$PSScriptRoot/Logging.psm1"

function Get-RemoteBaseUrl {
    param($cfg)

    if (-not $cfg -or -not $cfg.github) {
        throw "Missing github setting in configuration."
    }

    $username = $cfg.github.username
    $repository = $cfg.github.repository
    $branch = $cfg.github.branch

    if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($repository) -or [string]::IsNullOrWhiteSpace($branch)) {
        throw "github.username/repository/branch must be set in config.json"
    }

    return "https://raw.githubusercontent.com/$username/$repository/$branch"
}

function Poll-Remote {
    param(
        [string]$RemoteUrl,
        [string]$Path,
        [string]$LogFile = $null
    )

    try {
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) {
            Write-Log -Message "dir not found. creating now." -Level "Info" -LogFile $LogFile
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        Write-Log -Message "Downloading latest file from: $RemoteUrl" -Level "Info" -LogFile $LogFile

        $headers = @{
            "Cache-Control" = "no-cache, no-store, must-revalidate"
            "Pragma"        = "no-cache"
            "Expires"       = "0"
        }

        $tempPath = "$Path.tmp"

        Invoke-WebRequest -Uri $RemoteUrl -Headers $headers -OutFile $tempPath -ErrorAction Stop

        Move-Item -Force $tempPath $Path

        Write-Log -Message "File refreshed successfully at: $Path" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        if (Test-Path "$Path.tmp") {
            Remove-Item "$Path.tmp" -Force -ErrorAction SilentlyContinue
        }

        Write-Log -Message "Configuration refresh failed: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile
        return $false
    }
}

function Poll-RemoteConfig {
    param(
        $cfg,
        [string]$RemoteConfigUrl = $null,
        [string]$Path = $null,
        [string]$LogFile = $null
    )

    if ([string]::IsNullOrWhiteSpace($RemoteConfigUrl)) {
        Write-Log -Message "Remote config url not found. Creating now..." -Level "Info" -LogFile $LogFile
        $RemoteConfigUrl = Get-RemoteBaseUrl -cfg $cfg
        $RemoteConfigUrl = "$RemoteConfigUrl/Src/config.json"
        Write-Log -Message "Build Remote config url: $RemoteConfigUrl" -Level "Info" -LogFile $LogFile
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Log -Message "Path not found. creating default." -Level "Info" -LogFile $LogFile
        $Path = "$env:APPDATA\.wallpaper_countdown\config.json"
        Write-Log -Message "creating default Path: $Path" -Level "Info" -LogFile $LogFile
    }

    Poll-Remote -RemoteUrl $RemoteConfigUrl -Path $Path -LogFile $LogFile
}

function Poll-Img {
    param(
        $cfg,
        [string]$ImgRemoteUrl = $null,
        [string]$Path = $null,
        [string]$LogFile = $null
    )

    $imgPath = $cfg.github.imagePath

    if ([string]::IsNullOrWhiteSpace($ImgRemoteUrl)) {
        Write-Log -Message "ImgRemoteUrl not found. building now..." -Level "Info" -LogFile $LogFile
        $basicRemoteUrl = Get-RemoteBaseUrl -cfg $cfg
        $ImgRemoteUrl = "$basicRemoteUrl/$imgPath"
        Write-Log -Message "building Img remote url: $ImgRemoteUrl" -Level "Info" -LogFile $LogFile
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Log -Message "Path not found. building now..." -Level "Info" -LogFile $LogFile
        $Path = "$env:APPDATA\.wallpaper_countdown\cache\$imgPath"
        Write-Log -Message "build default Path: $Path" -Level "Info" -LogFile $LogFile
    }

    $result = Poll-Remote -RemoteUrl $ImgRemoteUrl -Path $Path -LogFile $LogFile
    return $result
}

Export-ModuleMember -Function Get-RemoteBaseUrl, Poll-RemoteConfig, Poll-Img
