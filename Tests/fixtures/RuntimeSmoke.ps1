# Windows runtime smoke test: original daily_run.ps1, isolated APPDATA, mocked network.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).ProviderPath
$isolatedRoot = Join-Path $env:TEMP ("acbd-security-smoke-" + [guid]::NewGuid().ToString('N'))
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $isolatedRoot 'AppData'
    $app = Join-Path $env:APPDATA '.wallpaper_countdown'
    $srcFolder = Join-Path $app 'Src'
    $backgrounds = Join-Path $app 'backgrounds'
    New-Item -ItemType Directory -Path $srcFolder, $backgrounds -Force | Out-Null

    $global:AcbdFixtureRemoteConfig = Join-Path $isolatedRoot 'remote-config.json'
    $global:AcbdFixtureRemoteImage = Join-Path $isolatedRoot 'remote-image.jpg'
    $global:AcbdFixtureFailImage = $false
    $global:AcbdFixtureConfigRequests = 0
    $global:AcbdFixtureImageRequests = 0

    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object System.Drawing.Bitmap(1600, 900)
    try { $bitmap.Save($global:AcbdFixtureRemoteImage, [System.Drawing.Imaging.ImageFormat]::Jpeg) }
    finally { $bitmap.Dispose() }

    $configuration = @{
        system = @{ taskName = 'ChangeWallpaperEveryDay'; appFolder = '.wallpaper_countdown' }
        github = @{ username = 'TsofnatMaman'; repository = 'AutoCustomBackgroundDesktop'; branch = 'main'; imagePath = 'backgrounds/1.jpg' }
        wallpaper = @{
            targetDate = (Get-Date).Date.AddDays(10).ToString('yyyy-MM-dd')
            text = 'Only {days} days remaining'
            time = '00:30'
            targets = @{ desktop = $false; lockScreen = $false }
        }
    }
    $configuration | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $global:AcbdFixtureRemoteConfig -Encoding UTF8
    Copy-Item -LiteralPath $global:AcbdFixtureRemoteConfig -Destination (Join-Path $srcFolder 'config.json')

    function global:Invoke-WebRequest {
        [CmdletBinding()]
        param([string]$Uri, [object]$Headers, [string]$OutFile, [int]$TimeoutSec)
        if ($Uri -match '/Src/config\.json$') {
            $global:AcbdFixtureConfigRequests++
            Copy-Item -LiteralPath $global:AcbdFixtureRemoteConfig -Destination $OutFile -Force
            return
        }
        if ($Uri -match '/backgrounds/1\.jpg$') {
            $global:AcbdFixtureImageRequests++
            if ($global:AcbdFixtureFailImage) { throw 'Intentionally simulated remote image download failure' }
            Copy-Item -LiteralPath $global:AcbdFixtureRemoteImage -Destination $OutFile -Force
            return
        }
        throw "Unexpected remote URI: $Uri"
    }

    $dailyScript = Join-Path $project 'Src\daily_run.ps1'
    & $dailyScript
    $base = Join-Path $app 'backgrounds\1.jpg'
    $rendered = Join-Path $app 'cache\backgrounds\1.jpg'
    $lastValid = Join-Path $app 'cache\last-valid\base.jpg'
    foreach ($required in @($base, $rendered, $lastValid)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing first-run output: $required" }
    }
    if ($global:AcbdFixtureConfigRequests -lt 1 -or $global:AcbdFixtureImageRequests -lt 1) {
        throw 'The daily runner did not perform both remote refresh operations.'
    }
    $resultSignature = [System.IO.File]::ReadAllBytes($rendered)
    if ($resultSignature[0] -ne 255 -or $resultSignature[1] -ne 216 -or $resultSignature[2] -ne 255) {
        throw 'Rendered wallpaper is not JPEG.'
    }
    $baseHash = (Get-FileHash -LiteralPath $base -Algorithm SHA256).Hash
    $renderHash = (Get-FileHash -LiteralPath $rendered -Algorithm SHA256).Hash
    if ($baseHash -eq $renderHash) { throw 'Rendered wallpaper is identical to the source image.' }

    Remove-Item -LiteralPath $base -Force
    $global:AcbdFixtureFailImage = $true
    & $dailyScript
    if (-not (Test-Path -LiteralPath $rendered -PathType Leaf)) {
        throw 'Daily run did not preserve rendered wallpaper after download failure.'
    }
    if (-not (Test-Path -LiteralPath $lastValid -PathType Leaf)) {
        throw 'Daily run did not preserve the last-valid image cache.'
    }
    $fallbackHash = (Get-FileHash -LiteralPath $rendered -Algorithm SHA256).Hash
    if ($renderHash -ne $fallbackHash) {
        throw 'The fallback renderer did not produce the same wallpaper content.'
    }
    if ($global:AcbdFixtureImageRequests -lt 2) { throw 'The second run did not retry the image download.' }
    Write-Output 'ACBD_WINDOWS_RUNTIME_SMOKE_PASS (remote sync, valid image, overlay, cache, fallback)'
}
finally {
    $env:APPDATA = $oldAppData
    Remove-Item -LiteralPath $isolatedRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path Function:\Invoke-WebRequest -ErrorAction SilentlyContinue
}
