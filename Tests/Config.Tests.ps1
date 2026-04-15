Import-Module "./Src/Modules/Config.psm1"
Import-Module "./Src/Modules/Logging.psm1"

Describe "Get-Config" {
    BeforeAll {
        # Mocking Write-Log so we don't need the actual Logging module loaded
        Mock Write-Log { }
        
        $TestConfigPath = "$TestDrive\config.json"
    }

    Context "Invalid Inputs" {
        It "Throws an error when the path is null or empty" {
            { Get-Config -ConfigFilePath "" } | Should -Throw "Config File Path () not provider or not exist."
        }

        It "Throws an error when the file does not exist" {
            $NonExistentPath = "C:\ThisFileDoesNotExist.json"
            { Get-Config -ConfigFilePath $NonExistentPath } | Should -Throw "Config File Path ($NonExistentPath) not provider or not exist."
        }
    }

    Context "Valid Configuration" {
        It "Returns a PSCustomObject when valid JSON is provided" {
            $JsonContent = '{"Setting": "Value", "Port": 8080}'
            $JsonContent | Out-File -FilePath $TestConfigPath -Encoding utf8
            
            $Result = Get-Config -ConfigFilePath $TestConfigPath
            
            $Result.Setting | Should -Be "Value"
            $Result.Port | Should -Be 8080
        }
    }

    Context "Malformed JSON" {
        It "Throws an error when JSON is invalid" {
            $InvalidJson = '{"Setting": "Value", "MissingQuote: 8080}'
            $InvalidJson | Out-File -FilePath $TestConfigPath -Encoding utf8

            { Get-Config -ConfigFilePath $TestConfigPath } | Should -Throw
        }
    }
}
