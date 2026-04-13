function Load-Configuration {
    param([string]$HiddenFolder)

    $baseUrl = "https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/config.json"
    $configPath = Join-Path $HiddenFolder "config.json"
    $configURL = "$baseUrl?ts=$(Get-Date -UFormat %s)"

    try {
        Write-Log "Fetching configuration from GitHub..."
        $response = Invoke-WebRequest -Uri $configURL -UseBasicParsing -ErrorAction Stop
        $jsonText = if ($response.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($response.Content) } else { $response.Content.ToString() }

        if ($jsonText.StartsWith([char]0xFEFF)) { $jsonText = $jsonText.Substring(1) }

        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($configPath, $jsonText, $utf8)
        return $jsonText | ConvertFrom-Json
    }
    catch {
        Write-Log "GitHub config fetch failed. Attempting local load." -Level Warning
        if (Test-Path $configPath) {
            return Get-Content $configPath -Raw | ConvertFrom-Json
        }
        throw "Configuration unavailable."
    }
}

Export-ModuleMember -Function Load-Configuration