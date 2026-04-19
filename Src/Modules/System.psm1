Import-Module "$PSScriptRoot/Logging.psm1"

function Set-Wallpaper {
    param(
        [string]$Path,
        [string]$LogFile
    )

    if (-not (Test-Path $Path)) {
        Write-Log -Message "Wallpaper file not found: $Path" -Level "Error" -LogFile $LogFile
        return $false
    }

    Write-Log -Message "Setting wallpaper to $Path" -Level "Info" -LogFile $LogFile

    try {
        $code = @"
        using System;
        using System.Runtime.InteropServices;
        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@

        if (-not ("Wallpaper" -as [type])) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }

        $result = [Wallpaper]::SystemParametersInfo(
            0x0014, # Action of changing wallpaper
            0,
            $Path,
            0x01 -bor 0x02 # Tells Windows: Update now, Save the setting
        )
        Write-Log -Message "Wallpaper set successfully (return code: $result)" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Failed to set wallpaper: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }
}

# Returns the numeric BackgroundType value from the registry, or -1 on failure.
# Known values: 0 = solid color / image file, 2 = Slideshow, 4 = Windows Spotlight
function Get-BackgroundType {
    try {
        $val = (Get-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" `
            -Name BackgroundType `
            -ErrorAction Stop).BackgroundType
        return [int]$val
    }
    catch {
        return -1
    }
}

function Get-CurrentWallpaperPath {
    # Check BackgroundType first so we can handle dynamic/managed modes correctly.
    # Type 4 = Windows Spotlight, Type 2 = Slideshow.
    # Neither can be fully restored via a single file path; TranscodedWallpaper is
    # the closest snapshot available and is documented as a limitation below.
    $bgType = Get-BackgroundType
    if ($bgType -eq 4 -or $bgType -eq 2) {
        # NOTE: Spotlight (4) and Slideshow (2) backgrounds are managed by Windows
        # and cannot be fully restored by setting a file path alone.  We capture the
        # TranscodedWallpaper cache file as a best-effort snapshot; the BackgroundType
        # is also stored in the backup so Restore-Wallpaper can re-enable the correct
        # mode via the registry instead of trying to set a static image.
        $transcodedPath = Join-Path $env:APPDATA "Microsoft\Windows\Themes\TranscodedWallpaper"
        if (Test-Path $transcodedPath) {
            return $transcodedPath
        }
        return ""
    }

    # Standard image / solid-color wallpaper: read the path from the Desktop key.
    try {
        $path = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -ErrorAction Stop).Wallpaper
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
            return $path
        }
    }
    catch { }

    # Registry value is empty or points to a missing file.
    # Fall back to the TranscodedWallpaper cache which Windows keeps up to date.
    $transcodedPath = Join-Path $env:APPDATA "Microsoft\Windows\Themes\TranscodedWallpaper"
    if (Test-Path $transcodedPath) {
        return $transcodedPath
    }

    return ""
}

function Backup-Wallpaper {
    param(
        [string]$BackupFile,
        [string]$LogFile
    )

    $currentPath = Get-CurrentWallpaperPath
    $bgType = Get-BackgroundType
    Write-Log -Message "Backing up wallpaper — path: '$currentPath', BackgroundType: $bgType" -Level "Info" -LogFile $LogFile

    try {
        $dir = Split-Path $BackupFile -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $backup = [PSCustomObject]@{
            Path           = $currentPath
            BackgroundType = $bgType
        }
        $json = $backup | ConvertTo-Json -Compress
        Set-Content -Path $BackupFile -Value $json -Encoding UTF8
        Write-Log -Message "Wallpaper backup saved to: $BackupFile" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Failed to save wallpaper backup: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }
}

function Restore-Wallpaper {
    param(
        [string]$BackupFile,
        [string]$LogFile
    )

    if (-not (Test-Path $BackupFile)) {
        Write-Log -Message "Wallpaper backup file not found: $BackupFile" -Level "Warning" -LogFile $LogFile
        return $false
    }

    $raw = (Get-Content $BackupFile -Raw).Trim()

    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-Log -Message "Backup file is empty; nothing to restore" -Level "Warning" -LogFile $LogFile
        return $false
    }

    # Parse JSON backup {Path, BackgroundType}
    try {
        $backup = $raw | ConvertFrom-Json
    }
    catch {
        Write-Log -Message "Backup file is not valid JSON; cannot restore: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }

    $bgType = [int]$backup.BackgroundType
    $originalPath = [string]$backup.Path

    Write-Log -Message "Restoring wallpaper — BackgroundType: $bgType, path: '$originalPath'" -Level "Info" -LogFile $LogFile

    # BackgroundType 2 (Slideshow) or 4 (Spotlight): restore via registry.
    # Setting a static file path is insufficient for these modes; we write the
    # BackgroundType back to the registry so Windows re-activates the correct mode.
    if ($bgType -eq 2 -or $bgType -eq 4) {
        try {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers"
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name BackgroundType -Value $bgType -Type DWord -ErrorAction Stop
            Write-Log -Message "Registry BackgroundType restored to $bgType" -Level "Info" -LogFile $LogFile
            return $true
        }
        catch {
            Write-Log -Message "Failed to restore registry BackgroundType: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
            return $false
        }
    }

    # BackgroundType 0 (or unknown): restore by setting the wallpaper file path.
    if ([string]::IsNullOrWhiteSpace($originalPath)) {
        Write-Log -Message "Backup path is empty; nothing to restore" -Level "Warning" -LogFile $LogFile
        return $false
    }

    return Set-Wallpaper -Path $originalPath -LogFile $LogFile
}

Export-ModuleMember -Function Set-Wallpaper, Get-CurrentWallpaperPath, Backup-Wallpaper, Restore-Wallpaper