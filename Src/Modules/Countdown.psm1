Import-Module "$PSScriptRoot/Logging.psm1"

function Get-DaysRemaining {
    param($cfg)

    $logFile = $null

    if (-not $cfg) {
        Write-Log -Message "config param not found or null." -Level "Warning" -LogFile $logFile
        throw "config param not found or null."
    }

    Write-Log -Message "calculating remaining days..."

    $targetDateValue = [string]$cfg.wallpaper.targetDate
    $targetDate = [datetime]::MinValue

    if (-not [datetime]::TryParse($targetDateValue, [ref]$targetDate)) {
        Write-Log -Message "date $targetDateValue invalid" -Level "Warning" -LogFile $logFile
        throw "Invalid wallpaper.targetDate value: '$targetDateValue'"
    }

    $days = ($targetDate.Date - (Get-Date).Date).Days

    Write-Log -Message "return remained days: $days." -Level "Info" -LogFile $logFile
    return $days
}

function Get-DaysText {
    param($cfg)

    $daysRemain = Get-DaysRemaining -cfg $cfg
    $text = $cfg.wallpaper.text
    $text = $text.Replace("{days}", [string]$daysRemain)

    return $text
}

Export-ModuleMember Get-DaysRemaining ,Get-DaysText