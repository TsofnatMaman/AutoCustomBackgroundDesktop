Import-Module "$PSScriptRoot/../Src/Modules/System.psm1"

Describe "Set-Wallpaper" {
    BeforeAll {
        # Setup the base mock for the entire Describe block
        Mock Write-Log { } -ModuleName System
    }

    Context "Validation" {
        It "Returns false if the wallpaper file path does not exist" {
            # Override/Define Test-Path for this specific test
            Mock Test-Path { return $false } -ModuleName System
            
            $result = Set-Wallpaper -Path "C:\NonExistent\Image.jpg"
            
            $result | Should -Be $false
            
            # Use Assert-MockCalled - this is the Pester 5 standard
            # We explicitly target the System module to find the mock
            Assert-MockCalled Write-Log -ModuleName System -ParameterFilter { 
                $Message -match "not found" 
            } -Times 1 -Exactly
        }
    }

    Context "Execution Flow" {
        It "Successfully calls the API flow when valid inputs are provided" {
            Mock Test-Path { return $true } -ModuleName System

            # Using a default Windows path
            $sampleImg = "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
            $result = Set-Wallpaper -Path $sampleImg

            $result | Should -Be $true

            # Verify the success log was captured
            Assert-MockCalled Write-Log -ModuleName System -ParameterFilter {
                $Message -match "successfully"
            } -Times 1 -Exactly
        }
    }
}

Describe "Backup-Wallpaper" {
    BeforeAll {
        Mock Write-Log { } -ModuleName System
    }

    It "Returns true and writes the backup file with the current wallpaper path" {
        Mock Get-CurrentWallpaperPath { return "C:\Windows\Web\Wallpaper\Windows\img0.jpg" } -ModuleName System

        $backupFile = "TestDrive:\backup\original_wallpaper.txt"
        $result = Backup-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Test-Path $backupFile | Should -Be $true
        (Get-Content $backupFile).Trim() | Should -Be "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
    }

    It "Creates the parent directory if it does not exist" {
        Mock Get-CurrentWallpaperPath { return "C:\some\path.jpg" } -ModuleName System

        $backupFile = "TestDrive:\new_backup_dir\original_wallpaper.txt"
        $result = Backup-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Test-Path (Split-Path $backupFile -Parent) | Should -Be $true
    }

    It "Returns false and logs an error when writing fails" {
        Mock Get-CurrentWallpaperPath { return "C:\some\path.jpg" } -ModuleName System
        Mock Set-Content { throw "Disk full" } -ModuleName System

        $result = Backup-Wallpaper -BackupFile "TestDrive:\fail\backup.txt"

        $result | Should -Be $false
        Should -Invoke Write-Log -ModuleName System -ParameterFilter {
            $Level -eq "Error" -and $Message -match "Disk full"
        }
    }
}

Describe "Restore-Wallpaper" {
    BeforeAll {
        Mock Write-Log { } -ModuleName System
    }

    It "Returns false and warns when the backup file does not exist" {
        Mock Test-Path { return $false } -ModuleName System

        $result = Restore-Wallpaper -BackupFile "TestDrive:\missing_backup.txt"

        $result | Should -Be $false
        Should -Invoke Write-Log -ModuleName System -ParameterFilter {
            $Level -eq "Warning" -and $Message -match "not found"
        }
    }

    It "Returns false and warns when the backup file is empty" {
        $emptyBackup = "TestDrive:\empty_backup.txt"
        Set-Content -Path $emptyBackup -Value "" -Encoding UTF8

        $result = Restore-Wallpaper -BackupFile $emptyBackup

        $result | Should -Be $false
        Should -Invoke Write-Log -ModuleName System -ParameterFilter {
            $Level -eq "Warning" -and $Message -match "empty"
        }
    }

    It "Calls Set-Wallpaper with the path from the backup file" {
        $backupFile = "TestDrive:\valid_backup.txt"
        Set-Content -Path $backupFile -Value "C:\Windows\Web\Wallpaper\Windows\img0.jpg" -Encoding UTF8

        Mock Set-Wallpaper { return $true } -ModuleName System

        $result = Restore-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Should -Invoke Set-Wallpaper -ModuleName System -ParameterFilter {
            $Path -eq "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
        }
    }
}