BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "..\modules\System.psm1"
    Import-Module $modulePath -Force
}

Describe "Utility Functions Tests" {

    Context "Get-DaysRemaining" {

        It "Should return 5 when the target date is 5 days in the future" {
            $FakeNow = Get-Date -Year 2026 -Month 1 -Day 1

            Mock Get-Date {
                if ($PSBoundParameters.Count -eq 0) {
                    return $FakeNow
                }
                else {
                    Microsoft.PowerShell.Utility\Get-Date @PSBoundParameters
                }
            } -ModuleName System

            $TargetDate = Get-Date -Year 2026 -Month 1 -Day 6
            $Result = Get-DaysRemaining -targetDate $TargetDate

            $Result | Should -Be 5
        }

        It "Should return a negative number if the date is in the past" {
            $FakeNow = Get-Date -Year 2026 -Month 1 -Day 10

            Mock Get-Date {
                if ($PSBoundParameters.Count -eq 0) {
                    return $FakeNow
                }
                else {
                    Microsoft.PowerShell.Utility\Get-Date @PSBoundParameters
                }
            } -ModuleName System

            $TargetDate = Get-Date -Year 2026 -Month 1 -Day 5
            $Result = Get-DaysRemaining -targetDate $TargetDate

            $Result | Should -Be -5
        }
    }

    Context "Acquire-Mutex" {

        It "Should return a Mutex object when the name is unique" {
            $UniqueName = "Global\TestMutex_$(Get-Random)"
            $Mutex = Acquire-Mutex -name $UniqueName
            
            $Mutex | Should -Not -BeNull
            $Mutex.GetType().Name | Should -Be "Mutex"

            $Mutex.ReleaseMutex()
            $Mutex.Dispose()
        }

        It "Should return null if the mutex is already held" {

            Mock New-Object {
                $fakeMutex = New-Object PSObject
                Add-Member -InputObject $fakeMutex -MemberType ScriptMethod -Name WaitOne -Value { return $false }
                return $fakeMutex
            } -ParameterFilter { $TypeName -eq "System.Threading.Mutex" } -ModuleName System

            $Result = Acquire-Mutex -name "test"

            $Result | Should -BeNull
        }
    }
}