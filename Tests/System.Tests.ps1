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
            
            Should -Invoke Write-Log -ModuleName System -ParameterFilter {
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
            Should -Invoke Write-Log -ModuleName System -ParameterFilter {
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

Describe "Get-CurrentWallpaperPath" {
    BeforeAll {
        Mock Write-Log { } -ModuleName System
    }

    It "Returns the registry path when it is set and the file exists" {
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ Wallpaper = "C:\Windows\Web\Wallpaper\Windows\img0.jpg" }
        } -ModuleName System

        Mock Test-Path {
            param($Path)
            return $Path -eq "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
        } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
    }

    It "Falls back to TranscodedWallpaper when the registry value is empty (e.g. Windows Spotlight)" {
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ Wallpaper = "" }
        } -ModuleName System

        $transcodedPath = Join-Path $env:APPDATA "Microsoft\Windows\Themes\TranscodedWallpaper"

        Mock Test-Path {
            param($Path)
            return $Path -eq $transcodedPath
        } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be $transcodedPath
    }

    It "Falls back to TranscodedWallpaper when the registry path points to a missing file" {
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ Wallpaper = "C:\MissingFile.jpg" }
        } -ModuleName System

        $transcodedPath = Join-Path $env:APPDATA "Microsoft\Windows\Themes\TranscodedWallpaper"

        Mock Test-Path {
            param($Path)
            return $Path -eq $transcodedPath
        } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be $transcodedPath
    }

    It "Returns empty string when neither the registry path nor TranscodedWallpaper exists" {
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ Wallpaper = "" }
        } -ModuleName System

        Mock Test-Path { return $false } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be ""
    }

    It "Returns empty string when the registry key throws an error and TranscodedWallpaper is missing" {
        Mock Get-ItemProperty { throw "Registry error" } -ModuleName System
        Mock Test-Path { return $false } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be ""
    }
}