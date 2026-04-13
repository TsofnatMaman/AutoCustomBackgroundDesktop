function Ensure-Admin {
    param([string]$LogFile)
    
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    Write-Log -Message "Admin check: isAdmin=$isAdmin" -Level "Debug" -LogFile $LogFile
    
    if (-not $isAdmin) {
        Write-Log -Message "Not running as admin. Requesting administrative privileges..." -Level "Warning" -LogFile $LogFile
        Write-Host "Requesting administrative privileges..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    
    Write-Log -Message "Running with administrative privileges" -Level "Info" -LogFile $LogFile
}

function Set-Wallpaper {
    param([string]$Path, [string]$LogFile)
    
    Write-Log -Message "Setting wallpaper to: $Path" -Level "Info" -LogFile $LogFile
    
    if (-not (Test-Path $Path)) {
        Write-Log -Message "Wallpaper file not found: $Path" -Level "Error" -LogFile $LogFile
        return $false
    }
    
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
        $result = [Wallpaper]::SystemParametersInfo(0x0014, 0, $Path, 0x01 -bor 0x02)
        Write-Log -Message "Wallpaper set successfully (return code: $result)" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Failed to set wallpaper: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $false
    }
}

function Acquire-Mutex {
    param($name, [string]$LogFile)

    Write-Log -Message "Attempting to acquire mutex: $name" -Level "Debug" -LogFile $LogFile
    
    try {
        $mutex = New-Object System.Threading.Mutex($false, $name)
        if (-not $mutex.WaitOne(0)) {
            Write-Log -Message "Failed to acquire mutex (already locked): $name" -Level "Warning" -LogFile $LogFile
            return $null
        }
        Write-Log -Message "Mutex acquired successfully: $name" -Level "Debug" -LogFile $LogFile
        return $mutex
    }
    catch {
        Write-Log -Message "Error acquiring mutex: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return $null
    }
}

function Get-DaysRemaining {
    param($targetDate, [string]$LogFile)

    try {
        $daysRemaining = ($targetDate.Date - (Get-Date).Date).Days
        Write-Log -Message "Target date: $($targetDate.Date), Days remaining: $daysRemaining" -Level "Debug" -LogFile $LogFile
        return $daysRemaining
    }
    catch {
        Write-Log -Message "Error calculating days remaining: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        return -1
    }
}

Import-Module (Join-Path $PSScriptRoot "Logging.psm1")

Export-ModuleMember -Function Ensure-Admin, Set-Wallpaper, Acquire-Mutex, Get-DaysRemaining