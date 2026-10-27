Import-Module "$PSScriptRoot/../Src/Modules/WallpaperTarget.psm1" -Force

Describe "Get-WallpaperTarget" {
    It "Defaults existing configurations to desktop" {
        (Get-WallpaperTarget -Config ([pscustomobject]@{ wallpaper = [pscustomobject]@{ time = '00:30' } })) | Should -Be 'desktop'
    }

    It "Accepts every documented destination" -TestCases @(
        @{ target = 'desktop' }
        @{ target = 'lockScreen' }
        @{ target = 'both' }
    ) {
        param($target)
        (Get-WallpaperTarget -Config ([pscustomobject]@{ wallpaper = [pscustomobject]@{ applyTo = $target } })) | Should -BeExactly $target
    }

    It "Rejects unsupported destinations instead of silently changing a different background" {
        { Get-WallpaperTarget -Config ([pscustomobject]@{ wallpaper = [pscustomobject]@{ applyTo = 'invalid' } }) } | Should -Throw '*Invalid wallpaper.applyTo*'
    }

    It "Defaults a null configuration to desktop" {
        (Get-WallpaperTarget -Config $null) | Should -Be 'desktop'
    }
}
