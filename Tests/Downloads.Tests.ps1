Import-Module "$PSScriptRoot/../Src/Modules/Downloads.psm1" -Force

Describe "Get-RemoteBaseUrl" {

    Context "Success Cases" {
        It "Should return the correct GitHub raw URL when all parameters are valid" {
            $mockCfg = @{
                github = @{
                    username   = "jdoe"
                    repository = "project-alpha"
                    branch     = "main"
                }
            }

            Get-RemoteBaseUrl -cfg $mockCfg | Should -Be "https://raw.githubusercontent.com/jdoe/project-alpha/main"
        }
    }

    Context "Failure Cases - Missing Keys" {
        It "Should throw an error if the cfg object is null" {
            { Get-RemoteBaseUrl -cfg $null } | Should -Throw "Missing github setting in configuration."
        }

        It "Should throw an error if the github key is missing" {
            { Get-RemoteBaseUrl -cfg @{ otherKey = "value" } } | Should -Throw "Missing github setting in configuration."
        }
    }

    Context "Failure Cases - Invalid Values" {
        $testCases = @(
            @{ Name = "Empty Username";  Username = "";     Repo = "repo"; Branch = "main" },
            @{ Name = "Whitespace Repo"; Username = "user"; Repo = " ";    Branch = "main" },
            @{ Name = "Null Branch";     Username = "user"; Repo = "repo"; Branch = $null }
        )

        foreach ($case in $testCases) {
            It "Should throw an error when provided: $($case.Name)" {
                $mockCfg = @{
                    github = @{
                        username   = $case.Username
                        repository = $case.Repo
                        branch     = $case.Branch
                    }
                }

                { Get-RemoteBaseUrl -cfg $mockCfg } |
                    Should -Throw "github.username/repository/branch must be set in config.json"
            }
        }
    }
}

Describe "Poll-RemoteConfig" {
    BeforeEach {
        Mock Write-Log {} -ModuleName "Downloads"
        Mock Get-RemoteBaseUrl { "https://mock.com" } -ModuleName "Downloads"

        Mock Invoke-WebRequest {
            param($Uri, $Headers, $OutFile, $TimeoutSec, $ErrorAction)

            @{
                system = @{
                    taskName  = "ChangeWallpaperEveryDay"
                    appFolder = ".wallpaper_countdown"
                }
                github = @{
                    username   = "user"
                    repository = "repo"
                    branch     = "main"
                    imagePath  = "backgrounds/2.jpg"
                }
                wallpaper = @{
                    targetDate = "2026-5-22"
                    text       = "...עוד {days} ימים"
                    time       = "00:30"
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFile -Encoding UTF8
        } -ModuleName "Downloads"

        $script:mockPath = "TestDrive:\config.json"
        $script:mockUrl = "https://example.com/config.json"
    }

    It "Should build the URL if RemoteConfigUrl is missing" {
        $cfg = @{ github = @{ username = "test"; repository = "repo"; branch = "main" } }

        $result = Poll-RemoteConfig -cfg $cfg -RemoteConfigUrl "" -Path $script:mockPath

        Should -Invoke -CommandName Get-RemoteBaseUrl -ModuleName "Downloads"
        $result | Should -Be $true
    }

    It "Should return true if Invoke-WebRequest succeeds and config is valid" {
        $result = Poll-RemoteConfig -RemoteConfigUrl $script:mockUrl -Path $script:mockPath

        $result | Should -Be $true
        Test-Path $script:mockPath | Should -Be $true
    }

    It "Should return false and keep existing config if Invoke-WebRequest fails" {
        '{ "old": true }' | Set-Content -Path $script:mockPath -Encoding UTF8

        Mock Invoke-WebRequest {
            throw "Connection Timeout"
        } -ModuleName "Downloads"

        $result = Poll-RemoteConfig -RemoteConfigUrl $script:mockUrl -Path $script:mockPath

        $result | Should -Be $false
        (Get-Content $script:mockPath -Raw) | Should -Match '"old"'
    }

    It "Should return false and keep existing config if downloaded JSON is invalid" {
        '{ "old": true }' | Set-Content -Path $script:mockPath -Encoding UTF8

        Mock Invoke-WebRequest {
            param($Uri, $Headers, $OutFile, $TimeoutSec, $ErrorAction)
            "not json" | Set-Content -Path $OutFile -Encoding UTF8
        } -ModuleName "Downloads"

        $result = Poll-RemoteConfig -RemoteConfigUrl $script:mockUrl -Path $script:mockPath

        $result | Should -Be $false
        (Get-Content $script:mockPath -Raw) | Should -Match '"old"'
    }

    It "Should send anti-caching headers with the request" {
        Poll-RemoteConfig -RemoteConfigUrl $script:mockUrl -Path $script:mockPath

        Should -Invoke -CommandName Invoke-WebRequest -ModuleName "Downloads" -ParameterFilter {
            $Headers.ContainsKey("Cache-Control") -and
            $Headers["Cache-Control"] -eq "no-cache, no-store, must-revalidate"
        }
    }
}

Describe "Poll-Img" {
    BeforeEach {
        Mock Write-Log {} -ModuleName "Downloads"
        Mock Get-RemoteBaseUrl { "https://mock.com" } -ModuleName "Downloads"
        Mock Poll-Remote { $true } -ModuleName "Downloads"

        $script:mockCfg = @{
            github = @{
                username   = "user"
                repository = "repo"
                branch     = "main"
                imagePath  = "images/bg.jpg"
            }
        }
    }

    It "Should build the Remote URL correctly when not provided" {
        Poll-Img -cfg $script:mockCfg -ImgRemoteUrl "" -Path "C:\test.jpg"

        Should -Invoke -CommandName Poll-Remote -ModuleName "Downloads" -ParameterFilter {
            $RemoteUrl -eq "https://mock.com/images/bg.jpg"
        }
    }

    It "Should use the default Src path if Path is null" {
        $oldAppData = $env:APPDATA

        try {
            $env:APPDATA = "C:\Users\Test\AppData\Roaming"

            Poll-Img -cfg $script:mockCfg -ImgRemoteUrl "https://manual.com/img.png" -Path ""

            $expectedPath = "C:\Users\Test\AppData\Roaming\.wallpaper_countdown\Src\images\bg.jpg"

            Should -Invoke -CommandName Poll-Remote -ModuleName "Downloads" -ParameterFilter {
                ($Path -replace '[\\/]+', '\') -eq ($expectedPath -replace '[\\/]+', '\')
            }
        }
        finally {
            $env:APPDATA = $oldAppData
        }
    }

    It "Should return the result of Poll-Remote" {
        Mock Poll-Remote { $true } -ModuleName "Downloads"

        Poll-Img -cfg $script:mockCfg -ImgRemoteUrl "http://test.com" -Path "C:\test.jpg" |
            Should -Be $true
    }

    It "Should return false when imagePath is empty" {
        $cfg = @{
            github = @{
                username   = "user"
                repository = "repo"
                branch     = "main"
                imagePath  = ""
            }
        }

        Poll-Img -cfg $cfg -Path "C:\test.jpg" | Should -Be $false
    }

    It "Should return false when imagePath has path traversal" {
        $cfg = @{
            github = @{
                username   = "user"
                repository = "repo"
                branch     = "main"
                imagePath  = "../secret.jpg"
            }
        }

        Poll-Img -cfg $cfg -Path "C:\test.jpg" | Should -Be $false
    }
}