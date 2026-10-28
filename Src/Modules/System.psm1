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
        # PowerShell 5.1 cannot dynamically dispatch GetResults on WinRT COM objects.
        # Bridge IAsyncOperation<T> and IAsyncAction to ordinary .NET Tasks instead.
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
        $extensions = [System.WindowsRuntimeSystemExtensions]
        $genericAsTask = $extensions.GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and
            $_.GetParameters().Count -eq 1
        } | Select-Object -First 1
        $actionAsTask = $extensions.GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and -not $_.IsGenericMethodDefinition -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.FullName -eq 'Windows.Foundation.IAsyncAction'
        } | Select-Object -First 1
        if (-not $genericAsTask -or -not $actionAsTask) {
            throw 'Windows Runtime async Task adapters are unavailable.'
        }

        $fileOperation = $storageType::GetFileFromPathAsync($resolvedPath)
        $fileTask = $genericAsTask.MakeGenericMethod(@($storageType)).Invoke($null, @($fileOperation))
        if (-not $fileTask.Wait([TimeSpan]::FromSeconds(30))) {
            throw 'Timed out opening the lock screen image.'
        }
        $file = $fileTask.GetAwaiter().GetResult()

        $setOperation = $lockScreenType::SetImageFileAsync($file)
        $setTask = $actionAsTask.Invoke($null, @($setOperation))
        if (-not $setTask.Wait([TimeSpan]::FromSeconds(30))) {
            throw 'Timed out updating the lock screen image.'
        }
        $setTask.GetAwaiter().GetResult()
        Write-Log -Message "Lock screen wallpaper set successfully: $resolvedPath" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Failed to update lock screen image (API may be blocked by Windows policy or process restrictions): $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }
}

Export-ModuleMember -Function Set-Wallpaper, Set-LockScreenWallpaper