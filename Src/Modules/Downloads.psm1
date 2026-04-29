Import-Module "$PSScriptRoot/Logging.psm1"

function Get-RemoteBaseUrl {
    param($cfg)

    if (-not $cfg -or -not $cfg.github) {
        throw "Missing github setting in configuration."
    }

    return "https://raw.githubusercontent.com/$($cfg.github.username)/$($cfg.github.repository)/$($cfg.github.branch)"
}

function Test-JsonConfigFile {
    param([string]$Path)

    try {
        $cfg = Get-Content $Path -Raw | ConvertFrom-Json

        if (-not $cfg.github.username) { return $false }
        if (-not $cfg.github.repository) { return $false }
        if (-not $cfg.github.branch) { return $false }
        if (-not $cfg.github.imagePath) { return $false }
        if (-not $cfg.wallpaper.targetDate) { return $false }
        if (-not $cfg.wallpaper.text) { return $false }
        if (-not $cfg.wallpaper.time) { return $false }

        return $true
    }
    catch {
        return $false
    }
}

function Test-ImageFile {
    param([string]$Path)

    $fs = $null
    $img = $null

    try {
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        if (-not (Test-Path $Path)) { return $false }

        Add-Type -AssemblyName System.Drawing

        $fs = [System.IO.File]::OpenRead($Path)
        $img = [System.Drawing.Image]::FromStream($fs, $true, $true)

        return ($img.Width -gt 0 -and $img.Height -gt 0)
    }
    catch {
        return $false
    }
    finally {
        if ($img) { $img.Dispose() }
        if ($fs) { $fs.Dispose() }
    }
}

function Poll-Remote {
    param(
        [string]$RemoteUrl,
        [string]$Path,
        [string]$LogFile = $null,
        [int]$TimeoutSec = 60,
        [scriptblock]$Validate = $null
    )

    $tempPath = $null

    try {
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $headers = @{
            "Cache-Control" = "no-cache, no-store, must-revalidate"
            "Pragma"        = "no-cache"
            "Expires"       = "0"
        }

        $tempPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"

        Write-Log -Message "Downloading latest file from: $RemoteUrl" -Level "Info" -LogFile $LogFile
        Invoke-WebRequest -Uri $RemoteUrl -Headers $headers -OutFile $tempPath -TimeoutSec $TimeoutSec -ErrorAction Stop

        if ($Validate -and -not (& $Validate $tempPath)) {
            throw "Downloaded file failed validation"
        }

        Move-Item -Force $tempPath $Path
        Write-Log -Message "File refreshed successfully at: $Path" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        if ($tempPath -and (Test-Path $tempPath)) {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        }

        Write-Log -Message "Download failed or invalid file. Keeping existing file: $Path. Error: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile
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
        $RemoteConfigUrl = "$(Get-RemoteBaseUrl -cfg $cfg)/Src/config.json"
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = "$env:APPDATA\.wallpaper_countdown\Src\config.json"
    }

    return Poll-Remote `
        -RemoteUrl $RemoteConfigUrl `
        -Path $Path `
        -LogFile $LogFile `
        -Validate { param($p) Test-JsonConfigFile -Path $p }
}

function Poll-Img {
    param(
        $cfg,
        [string]$ImgRemoteUrl = $null,
        [string]$Path = $null,
        [string]$LogFile = $null
    )

    $imgPath = $cfg.github.imagePath

    if ([string]::IsNullOrWhiteSpace($imgPath)) {
        Write-Log -Message "imagePath is empty" -Level "Warning" -LogFile $LogFile
        return $false
    }

    $imgPath = $imgPath -replace '\\', '/'
    $imgPath = $imgPath -replace '^[/]+', ''

    if ($imgPath -match '\.\.') {
        Write-Log -Message "imagePath contains unsafe path traversal" -Level "Warning" -LogFile $LogFile
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($ImgRemoteUrl)) {
        $ImgRemoteUrl = "$(Get-RemoteBaseUrl -cfg $cfg)/$imgPath"
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = "$env:APPDATA\.wallpaper_countdown\Src\$imgPath"
    }

    return Poll-Remote `
        -RemoteUrl $ImgRemoteUrl `
        -Path $Path `
        -LogFile $LogFile `
        -Validate { param($p) Test-ImageFile -Path $p }
}

Export-ModuleMember -Function Get-RemoteBaseUrl, Poll-RemoteConfig, Poll-Img, Test-ImageFile