Import-Module "./Cleanup.psm1"

Describe "Cleanup Module - Uninstall Logic" {

    BeforeEach {
        Mock Unregister-ScheduledTask { }
        Mock Remove-Item { }
        Mock Test-Path { return $true }
        Mock Write-Log { }
    }

    Context "Remove-ScheduledTaskSafe" {
        It "Calls Unregister-ScheduledTask with correct parameters" {
            Remove-ScheduledTaskSafe -TaskName "TestTask"
            
            Assert-MockCalled Unregister-ScheduledTask -ParameterFilter {
                $TaskName -eq "TestTask"
            }
        }
    }

    Context "Remove-HiddenFolderSafe" {
        It "Removes folder if it exists" {
            Mock Test-Path { return $true }
            Remove-HiddenFolderSafe -HiddenFolder "C:\Temp\Hidden"
            Assert-MockCalled Remove-Item
        }
    }

    Context "Uninstall-Project" {
        It "Triggers all removal steps" {
            Mock Remove-ScheduledTaskSafe { }
            Mock Remove-HiddenFolderSafe { }
        }
    }
}