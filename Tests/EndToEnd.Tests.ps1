# Executes the original daily-run entry point in a disposable Windows user-data folder.
Describe 'End-to-end wallpaper runtime (Windows isolated test)' {
    It 'syncs config and image, renders JPEG and uses cached fallback' {
        $smokeScript = Join-Path $PSScriptRoot 'fixtures\RuntimeSmoke.ps1'
        $output = & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $smokeScript 2>&1
        $LASTEXITCODE | Should -Be 0 -Because (($output | Out-String) -replace '\r', '')
        ($output | Out-String) | Should -Match 'ACBD_WINDOWS_RUNTIME_SMOKE_PASS'
    }
}
