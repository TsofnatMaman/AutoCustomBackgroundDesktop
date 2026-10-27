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
        if ($result -eq 0) {
            Write-Log -Message "SystemParametersInfo rejected the wallpaper update." -Level "Error" -LogFile $LogFile
            return $false
        }
        Write-Log -Message "Wallpaper set successfully (return code: $result)" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Failed to set wallpaper: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }
}

# Use the supported Windows Runtime API rather than modifying protected system files
# or installing a persistent machine-wide lock-screen policy.
function Set-LockScreenWallpaper {
    param(
        [string]$Path,
        [string]$LogFile
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Log -Message "Lock screen image file not found: $Path" -Level "Error" -LogFile $LogFile
        return $false
    }

    try {
        if ($env:OS -ne 'Windows_NT') {
            throw 'The Windows lock screen API is only available on Windows.'
        }

        # WinRT SetImageFileAsync is unsupported from an x86 console process on x64.
        if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
            throw 'Run the app in a 64-bit PowerShell process to update the lock screen.'
        }

        $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
        $storageType = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
        $lockScreenType = [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]
        $null = [Windows.Foundation.IAsyncOperation`1,Windows.Foundation,ContentType=WindowsRuntime]
        $null = [Windows.Foundation.IAsyncAction,Windows.Foundation,ContentType=WindowsRuntime]

        # Windows Runtime metadata is not a CLR assembly and cannot be passed to Add-Type.
        # Poll the WinRT async operations directly; GetResults surfaces API failures.
        $fileOperation = $storageType::GetFileFromPathAsync($resolvedPath)
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ([string]$fileOperation.Status -eq 'Started') {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Timed out opening the lock screen image.' }
            Start-Sleep -Milliseconds 50
        }
        $file = $fileOperation.GetResults()

        $setOperation = $lockScreenType::SetImageFileAsync($file)
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ([string]$setOperation.Status -eq 'Started') {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Timed out updating the lock screen image.' }
            Start-Sleep -Milliseconds 50
        }
        $setOperation.GetResults()
        Write-Log -Message "Lock screen wallpaper set successfully: $resolvedPath" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Failed to update lock screen image (API may be blocked by Windows policy or process restrictions): $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }
}

Export-ModuleMember -Function Set-Wallpaper, Set-LockScreenWallpaper