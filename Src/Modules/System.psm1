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

function Get-CurrentWallpaperPath {
    param(
        [string]$LogFile
    )

    try {
        $path = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -ErrorAction Stop).Wallpaper

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            return $path
        }

        # Path is empty — determine why so we can log a useful message
        $isSpotlight = $false
        try {
            $cdmKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            $spotlightValue = (Get-ItemProperty -Path $cdmKey -Name "SubscribedContent-338388Enabled" -ErrorAction Stop)."SubscribedContent-338388Enabled"
            if ($spotlightValue -eq 1) {
                $isSpotlight = $true
            }
        }
        catch {
            # ContentDeliveryManager key or value not present — not Spotlight
        }

        if ($isSpotlight) {
            Write-Log -Message "Windows Spotlight is active for the desktop; wallpaper path cannot be captured for restore." -Level "Warning" -LogFile $LogFile
        }
        else {
            Write-Log -Message "Wallpaper registry value is empty (solid color or system default); no file path to back up." -Level "Warning" -LogFile $LogFile
        }

        return ""
    }
    catch {
        Write-Log -Message "Failed to read wallpaper registry value: $($_.Exception.Message)" -Level "Warning" -LogFile $LogFile
        return ""
    }
}

function Backup-Wallpaper {
    param(
        [string]$BackupFile,
        [string]$LogFile
    )

    $currentPath = Get-CurrentWallpaperPath -LogFile $LogFile
    Write-Log -Message "Backing up current wallpaper path: '$currentPath'" -Level "Info" -LogFile $LogFile

    try {
        $dir = Split-Path $BackupFile -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -Path $BackupFile -Value $currentPath -Encoding UTF8
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

    $originalPath = (Get-Content $BackupFile -Raw).Trim()
    Write-Log -Message "Restoring original wallpaper from backup: '$originalPath'" -Level "Info" -LogFile $LogFile

    if ([string]::IsNullOrWhiteSpace($originalPath)) {
        Write-Log -Message "Backup file is empty; nothing to restore" -Level "Warning" -LogFile $LogFile
        return $false
    }

    return Set-Wallpaper -Path $originalPath -LogFile $LogFile
}

Export-ModuleMember -Function Set-Wallpaper, Get-CurrentWallpaperPath, Backup-Wallpaper, Restore-Wallpaper