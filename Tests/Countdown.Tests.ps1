Import-Module "$PSScriptRoot/../Src/Modules/Countdown.psm1" -Force

Describe "Days Calculation Module" {
    BeforeAll {
        # Global Mock for Write-Log inside the module
        Mock Write-Log { } -ModuleName Countdown
    }

    Context "Get-DaysRemaining" {

        It "Throws an error if the config object is null" {
            { Get-DaysRemaining -cfg $null } | Should -Throw "config param not found or null."
        }

        It "Correctly calculates days between today and a future date" {
            # FIX: Added -ModuleName so the function inside the .psm1 uses the mock date
            Mock Get-Date { return [datetime]"2026-04-10" } -ModuleName Countdown
            
            $mockCfg = @{
                wallpaper = @{
                    targetDate = "2026-04-15"
                }
            }

            $result = Get-DaysRemaining -cfg $mockCfg
            $result | Should -Be 5
        }

        It "Throws an error if the date format is invalid" {
            $invalidCfg = @{
                wallpaper = @{
                    targetDate = "Not-A-Date"
                }
            }

            { Get-DaysRemaining -cfg $invalidCfg } | Should -Throw "Invalid wallpaper.targetDate value: 'Not-A-Date'"
        }
    }

    Context "Get-DaysText" {
        It "Replaces the {days} placeholder with the calculated value" {
            # FIX: Added -ModuleName so Get-DaysText uses this mock instead of the real function
            Mock Get-DaysRemaining { return 10 } -ModuleName Countdown
            
            $mockCfg = @{
                wallpaper = @{
                    text = "Only {days} days left!"
                }
            }

            $result = Get-DaysText -cfg $mockCfg
            $result | Should -Be "Only 10 days left!"
        }
    }
}
