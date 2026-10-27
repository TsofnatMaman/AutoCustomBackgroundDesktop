Import-Module "$PSScriptRoot/../Src/Modules/WallpaperTarget.psm1" -Force
Describe "Get-WallpaperTargets" {
    It "Defaults older configs to desktop only" {
        $result = Get-WallpaperTargets -Config ('{"wallpaper":{"time":"00:30"}}' | ConvertFrom-Json)
        $result.desktop | Should -BeTrue
        $result.lockScreen | Should -BeFalse
    }
    It "Supports independent destinations" -TestCases @(
        @{ desktop = $true; lockScreen = $false }
        @{ desktop = $false; lockScreen = $true }
        @{ desktop = $true; lockScreen = $true }
        @{ desktop = $false; lockScreen = $false }
    ) {
        param($desktop, $lockScreen)
        $config = ('{"wallpaper":{"targets":{"desktop":' + $desktop.ToString().ToLowerInvariant() + ',"lockScreen":' + $lockScreen.ToString().ToLowerInvariant() + '}}}') | ConvertFrom-Json
        $result = Get-WallpaperTargets -Config $config
        $result.desktop | Should -Be $desktop
        $result.lockScreen | Should -Be $lockScreen
    }
    It "Rejects missing target values" {
        { Get-WallpaperTargets -Config ('{"wallpaper":{"targets":{"desktop":true}}}' | ConvertFrom-Json) } | Should -Throw
    }
    It "Rejects nonboolean target values" {
        { Get-WallpaperTargets -Config ('{"wallpaper":{"targets":{"desktop":"true","lockScreen":false}}}' | ConvertFrom-Json) } | Should -Throw
    }
    It "Rejects unknown target names" {
        { Get-WallpaperTargets -Config ('{"wallpaper":{"targets":{"desktop":true,"lockScreen":false,"mobile":true}}}' | ConvertFrom-Json) } | Should -Throw
    }
    It "Supports legacy applyTo values" {
        $result = Get-WallpaperTargets -Config ('{"wallpaper":{"applyTo":"both"}}' | ConvertFrom-Json)
        $result.desktop | Should -BeTrue
        $result.lockScreen | Should -BeTrue
    }
}
