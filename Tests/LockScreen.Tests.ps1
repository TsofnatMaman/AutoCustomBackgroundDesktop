Import-Module "$PSScriptRoot/../Src/Modules/System.psm1" -Force

Describe "Set-LockScreenWallpaper" {
    BeforeAll { Mock Write-Log { } -ModuleName System }

    It "Rejects a missing image without attempting a Windows API call" {
        Mock Test-Path { return $false } -ModuleName System
        Set-LockScreenWallpaper -Path 'C:\does-not-exist.jpg' | Should -BeFalse
    }

    It "Reports a failed Windows API initialization without throwing" {
        Mock Test-Path { return $true } -ModuleName System
        Mock Resolve-Path { throw 'Cannot resolve image' } -ModuleName System
        Set-LockScreenWallpaper -Path 'C:\sample.jpg' | Should -BeFalse
    }
}
