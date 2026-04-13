Import-Module "./modules/Logging.psm1"
Import-Module "./modules/Config.psm1"

Describe "Load-Configuration Tests" {

    BeforeAll {
        $TestRoot = Join-Path $env:TEMP "PesterTests_$(Get-Random)"
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

        $ConfigContent = @{
            AppName = "MyApp"
            Version = "1.0.0"
            Settings = @{
                Timeout = 30
                Enabled = $true
            }
        } | ConvertTo-Json

        $ValidFilePath = Join-Path $TestRoot "config.json"
        $ConfigContent | Set-Content -Path $ValidFilePath
    }

    AfterAll {
        if (Test-Path $TestRoot) {
            Remove-Item -Path $TestRoot -Recurse -Force
        }
    }

    Context "Valid Configuration" {
        It "Should load and parse a valid config.json file correctly" {
            $Result = Load-Configuration -Root $TestRoot

            $Result.AppName | Should -Be "MyApp"
            $Result.Version | Should -Be "1.0.0"
            $Result.Settings.Timeout | Should -Be 30
        }
    }

    Context "Error Handling" {
        It "Should throw an error when config.json is missing" {
            $EmptyFolder = Join-Path $TestRoot "Empty"
            New-Item -ItemType Directory -Path $EmptyFolder -Force | Out-Null

            { Load-Configuration -Root $EmptyFolder } | Should -Throw "config.json not found at *"
        }

        It "Should throw an error when the root path does not exist" {
            $InvalidPath = "C:\NonExistentPath_$(Get-Random)"

            { Load-Configuration -Root $InvalidPath } | Should -Throw "config.json not found at *"
        }
    }

    Context "Output Type" {
        It "Should return a PSCustomObject" {
            $Result = Load-Configuration -Root $TestRoot
            $Result.GetType().Name | Should -Be "PSCustomObject"
        }
    }
}