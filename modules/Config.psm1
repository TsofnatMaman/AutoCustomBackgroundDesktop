function Load-Configuration {
    param([string]$Root)

    $path = Join-Path $Root "config.json"

    if (-not (Test-Path $path)) {
        throw "config.json not found at $path"
    }

    return Get-Content $path -Raw | ConvertFrom-Json
}

Export-ModuleMember -Function Load-Configuration