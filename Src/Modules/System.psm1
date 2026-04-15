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

Export-ModuleMember -Function Set-Wallpaper