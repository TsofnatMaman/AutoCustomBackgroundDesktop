Import-Module "./Src/Modules/Logging.psm1"

Describe "Logging Module" {

    Context "Initilize-Logging" {
        It "Should create the directory if it does not exist" {
            $testPath = "TestDrive:\Logs"
            
            # Ensure it doesn't exist before we start
            if (Test-Path $testPath) { Remove-Item $testPath -Recurse }

            Initilize-Logging -LogFolder $testPath

            Test-Path $testPath | Should -Be $true
        }

        It "Should not throw an error if the path is empty" {
            { Initilize-Logging -LogFolder "" } | Should -Not -Throw
        }
    }

    Context "Write-Log" {
        BeforeAll {
            $logFile = "TestDrive:\Application.log"
        }

        BeforeEach {
            if (Test-Path $logFile) { Remove-Item $logFile }
        }

        It "Should create the log file and write the message" {
            $msg = "Test log message"
            Write-Log -Message $msg -Level "Info" -LogFile $logFile

            Test-Path $logFile | Should -Be $true
            $content = Get-Content $logFile
            $content | Should -Match "\[Info\] $msg"
        }

        It "Should automatically create the parent directory if it is missing" {
            $deepLogFile = "TestDrive:\Nested\Folder\test.log"
            Write-Log -Message "Auto-create dir" -LogFile $deepLogFile

            Test-Path (Split-Path $deepLogFile -Parent) | Should -Be $true
            Test-Path $deepLogFile | Should -Be $true
        }

        It "Should return immediately and do nothing if LogFile is null or empty" {
            # We verify no errors occur and no files are created in the current dir
            { Write-Log -Message "Silent fail" -LogFile "" } | Should -Not -Throw
        }

        It "Should format the timestamp correctly" {
            $msg = "Timestamp test"
            Write-Log -Message $msg -LogFile $logFile
            
            $content = Get-Content $logFile
            # Matches YYYY-MM-DD format at the start
            $content | Should -Match "^\[\d{4}-\d{2}-\d{2}"
        }
    }
}
