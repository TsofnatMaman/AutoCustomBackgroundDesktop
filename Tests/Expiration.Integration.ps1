# Integration test for expiration handoff, executed on Windows PowerShell 5.1.
# Uses an isolated user profile and a safe test-double uninstaller. Does not alter
# the runner's actual wallpaper, installed applications, or scheduled tasks.
$ErrorActionPreference = 'Stop'
$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
$testRoot = Join-Path $env:RUNNER_TEMP ('wallpaper-expiry-e2e-' + [guid]::NewGuid().ToString('N'))
if (-not $env:RUNNER_TEMP) {
    $testRoot = Join-Path $env:TEMP ('wallpaper-expiry-e2e-' + [guid]::NewGuid().ToString('N'))
}

try {
    foreach ($scenario in @(
        @{ Name = 'expired'; Target = '2000-01-01'; ShouldUninstall = $true },
        @{ Name = 'future'; Target = '2999-01-01'; ShouldUninstall = $false }
    )) {
        $root = Join-Path $testRoot $scenario.Name
        $env:APPDATA = Join-Path $root 'Roaming'
        $env:LOCALAPPDATA = Join-Path $root 'Local'
        $appDir = Join-Path $env:APPDATA '.wallpaper_countdown'
        $src = Join-Path $appDir 'Src'
        New-Item -ItemType Directory -Path $src -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\Src\Modules') -Destination $src -Recurse
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\Src\daily_run.ps1') -Destination $src

        # No external network is used in this integration test.
        @'
function Poll-RemoteConfig { return $false }
function Poll-Img { return $false }
function Test-ImageFile { return $false }
Export-ModuleMember -Function Poll-RemoteConfig, Poll-Img, Test-ImageFile
'@ | Set-Content -LiteralPath (Join-Path $src 'Modules\Downloads.psm1') -Encoding UTF8

        $config = @{
            system = @{ taskName = 'WallpaperE2ETest' }
            github = @{ username = 'test'; repository = 'test'; branch = 'test'; imagePath = 'backgrounds\unused.jpg' }
            wallpaper = @{ targetDate = $scenario.Target; text = 'Remaining {days}'; time = '00:30'; targets = @{ desktop = $true; lockScreen = $false } }
        }
        $config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $src 'config.json') -Encoding UTF8

        $mockUninstaller = @'
$path = Join-Path $env:APPDATA '.wallpaper_countdown'
$evidence = Join-Path $env:LOCALAPPDATA 'uninstall-evidence.txt'
if (-not (Test-Path -LiteralPath $path)) { throw 'Missing installation fixture' }
Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
Set-Content -LiteralPath $evidence -Value 'uninstalled-after-parent-exit' -Encoding UTF8
'@
        $mockUninstaller | Set-Content -LiteralPath (Join-Path $src 'uninstall.ps1') -Encoding UTF8

        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', ('"' + (Join-Path $src 'daily_run.ps1') + '"')
        ) -PassThru -Wait
        $evidencePath = Join-Path $env:LOCALAPPDATA 'uninstall-evidence.txt'
        $logPath = Join-Path $env:LOCALAPPDATA 'WallpaperCountdown\logs\expiration-uninstall.log'

        if ($scenario.ShouldUninstall) {
            if ($process.ExitCode -ne 0) {
                throw "Expired countdown returned failure exit code $($process.ExitCode)"
            }
            $deadline = (Get-Date).AddSeconds(35)
            while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $logPath)) {
                Start-Sleep -Milliseconds 300
            }
            if (-not (Test-Path -LiteralPath $logPath)) { throw 'Detached cleanup never wrote its result log' }
            $log = Get-Content -LiteralPath $logPath -Raw
            if ($log -notmatch 'Automatic uninstall completed') { throw "Detached cleanup failed: $log" }
            if (Test-Path -LiteralPath $appDir) { throw 'Installation folder not removed' }
            if (-not (Test-Path -LiteralPath $evidencePath)) { throw 'Isolated uninstaller did not execute' }
        }
        else {
            if (-not (Test-Path -LiteralPath $appDir)) { throw 'Future-dated installation was removed' }
            if (Test-Path -LiteralPath $evidencePath) { throw 'Uninstaller ran before expiration' }
            if (Test-Path -LiteralPath $logPath) { throw 'Unexpected cleanup process launched for future date' }
        }
        Write-Host "PASS $($scenario.Name): expected cleanup behavior verified."
    }
}
finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
