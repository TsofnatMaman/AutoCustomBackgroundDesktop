Import-Module "./Src/Modules/Downloads.psm1"

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

            $expectedUrl = "https://raw.githubusercontent.com/jdoe/project-alpha/main"
            $result = Get-RemoteBaseUrl -cfg $mockCfg
            
            $result | Should -Be $expectedUrl
        }
    }

    Context "Failure Cases - Missing Keys" {
        It "Should throw an error if the cfg object is null" {
            { Get-RemoteBaseUrl -cfg $null } | Should -Throw "Missing github setting in configuration."
        }

        It "Should throw an error if the github key is missing" {
            $mockCfg = @{ otherKey = "value" }
            { Get-RemoteBaseUrl -cfg $mockCfg } | Should -Throw "Missing github setting in configuration."
        }
    }

    Context "Failure Cases - Invalid Values" {
        $testCases = @(
            @{ Name = "Empty Username";   Username = "";       Repo = "repo"; Branch = "main" },
            @{ Name = "Whitespace Repo";  Username = "user";   Repo = " ";    Branch = "main" },
            @{ Name = "Null Branch";      Username = "user";   Repo = "repo"; Branch = $null }
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

                { Get-RemoteBaseUrl -cfg $mockCfg } | Should -Throw "github.username/repository/branch must be set in config.json"
            }
        }
    }
}

Describe "Poll-RemoteConfig" {
    BeforeAll {
        # CRITICAL: Use -ModuleName "Downloads" so the module uses the mock 
        # instead of looking for the real (and potentially missing) Write-Log
        Mock Write-Log {} -ModuleName "Downloads"
        Mock Get-RemoteBaseUrl { return "https://mock.com" } -ModuleName "Downloads"
        Mock Invoke-WebRequest {} -ModuleName "Downloads"

        $mockPath = "TestDrive:\config.json"
        $mockUrl = "https://example.com/config.json"
    }

    Context "URL Generation" {
        It "Should build the URL if RemoteConfigUrl is missing" {
            $cfg = @{ github = @{ username = "test" } }
            $result = Poll-RemoteConfig -cfg $cfg -RemoteConfigUrl "" -Path $mockPath
            
            # Verify internal call was made
            Should -Invoke -CommandName Get-RemoteBaseUrl -ModuleName "Downloads"
            $result | Should -Be $true
        }
    }

    Context "Downloading Files" {
        It "Should return true if Invoke-WebRequest succeeds" {
            $result = Poll-RemoteConfig -RemoteConfigUrl $mockUrl -Path $mockPath
            $result | Should -Be $true
        }

        It "Should return false and log a warning if Invoke-WebRequest fails" {
            # Mock specifically for this test
            Mock Invoke-WebRequest { throw "Connection Timeout" } -ModuleName "Downloads"

            $result = Poll-RemoteConfig -RemoteConfigUrl $mockUrl -Path $mockPath

            $result | Should -Be $false
            Should -Invoke -CommandName Write-Log -ModuleName "Downloads" -ParameterFilter { 
                $Level -eq "Warning" -and $Message -match "Connection Timeout" 
            }
        }
    }

    Context "Cache Headers" {
        It "Should send anti-caching headers with the request" {
            # Act
            Poll-RemoteConfig -RemoteConfigUrl $mockUrl -Path $mockPath

            # Assert: Add -ModuleName "Downloads" here!
            Should -Invoke -CommandName Invoke-WebRequest -ModuleName "Downloads" -ParameterFilter {
                $Headers.ContainsKey("Cache-Control") -and 
                $Headers["Cache-Control"] -eq "no-cache, no-store, must-revalidate"
            }
        }
    }
}

Describe "Poll-Img" {
    BeforeAll {
        Mock Write-Log {} -ModuleName "Downloads"
        Mock Get-RemoteBaseUrl { return "https://mock.com" } -ModuleName "Downloads"
        Mock Poll-Remote { return $true } -ModuleName "Downloads"

        $mockCfg = @{
            github = @{
                imagePath = "images/bg.jpg"
            }
        }
    }

    Context "URL and Path Construction" {
        It "Should build the Remote URL correctly when not provided" {
            Poll-Img -cfg $mockCfg -ImgRemoteUrl "" -Path "C:/test.jpg"
            
            Should -Invoke -CommandName Poll-Remote -ModuleName "Downloads" -ParameterFilter {
                $RemoteUrl -eq "https://mock.com/images/bg.jpg"
            }
        }

        It "Should use the default APPDATA path if Path is null" {
            # Setup environment variable for test consistency
            $env:APPDATA = "C:\Users\Test\AppData\Roaming"
            
            Poll-Img -cfg $mockCfg -ImgRemoteUrl "https://manual.com/img.png" -Path ""

            $expectedPath = "C:\Users\Test\AppData\Roaming/.wallpaper_countdown/cache/images/bg.jpg"
            
            Should -Invoke -CommandName Poll-Remote -ModuleName "Downloads" -ParameterFilter {
                $Path -eq $expectedPath
            }
        }
    }

    Context "Execution" {
        It "Should return the result of Poll-Remote" {
            Mock Poll-Remote { return $true } -ModuleName "Downloads"
            $result = Poll-Img -cfg $mockCfg -ImgRemoteUrl "http://test.com" -Path "C:/test.jpg"
            $result | Should -Be $true
        }
    }
}
