function Load-Configuration {
    param([string]$Root)

    $path = Join-Path $Root "config.json"
    return Get-Content $path -Raw | ConvertFrom-Json
}

Export-ModuleMember -Function Load-Configuration