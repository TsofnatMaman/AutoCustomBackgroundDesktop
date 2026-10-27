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

        # PowerShell 5.1 cannot await IAsyncOperation/IAsyncAction directly. A small
        # C# bridge awaits both operations so failures are reported, not fire-and-forgotten.
        if (-not ('WallpaperLockScreenBridge' -as [type])) {
            $bridge = @"
using System;
using Windows.Foundation;
using Windows.Storage;
using Windows.System.UserProfile;
public static class WallpaperLockScreenBridge
{
    public static void SetImage(string path)
    {
        var fileOperation = StorageFile.GetFileFromPathAsync(path);
        var fileCompletion = new System.Threading.Tasks.TaskCompletionSource<StorageFile>();
        fileOperation.Completed = (operation, status) =>
        {
            try { fileCompletion.TrySetResult(operation.GetResults()); }
            catch (Exception ex) { fileCompletion.TrySetException(ex); }
        };
        var file = fileCompletion.Task.GetAwaiter().GetResult();
        var setOperation = LockScreen.SetImageFileAsync(file);
        var setCompletion = new System.Threading.Tasks.TaskCompletionSource<bool>();
        setOperation.Completed = (operation, status) =>
        {
            try { operation.GetResults(); setCompletion.TrySetResult(true); }
            catch (Exception ex) { setCompletion.TrySetException(ex); }
        };
        setCompletion.Task.GetAwaiter().GetResult();
    }
}
"@
            Add-Type -TypeDefinition $bridge -ReferencedAssemblies @(
                [System.IO.Path]::Combine($env:WINDIR, 'System32', 'WinMetadata', 'Windows.winmd')
            ) -ErrorAction Stop
        }

        [WallpaperLockScreenBridge]::SetImage($resolvedPath)
        Write-Log -Message "Lock screen wallpaper set successfully: $resolvedPath" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Failed to update lock screen image (API may be blocked by Windows policy or process restrictions): $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }
}

Export-ModuleMember -Function Set-Wallpaper, Set-LockScreenWallpaper