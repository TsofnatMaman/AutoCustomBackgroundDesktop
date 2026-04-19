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

    It "Returns true and writes a JSON backup file with the path and BackgroundType" {
        Mock Get-CurrentWallpaperPath { return "C:\Windows\Web\Wallpaper\Windows\img0.jpg" } -ModuleName System
        # Get-BackgroundType reads from registry via Get-ItemProperty
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ BackgroundType = 0 }
        } -ModuleName System

        $backupFile = "TestDrive:\backup\original_wallpaper.json"
        $result = Backup-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Test-Path $backupFile | Should -Be $true

        $json = Get-Content $backupFile -Raw | ConvertFrom-Json
        $json.Path | Should -Be "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
        $json.BackgroundType | Should -Be 0
    }

    It "Creates the parent directory if it does not exist" {
        Mock Get-CurrentWallpaperPath { return "C:\some\path.jpg" } -ModuleName System
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ BackgroundType = 0 }
        } -ModuleName System

        $backupFile = "TestDrive:\new_backup_dir\original_wallpaper.json"
        $result = Backup-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Test-Path (Split-Path $backupFile -Parent) | Should -Be $true
    }

    It "Stores BackgroundType 2 (Slideshow) in the backup JSON" {
        Mock Get-CurrentWallpaperPath { return "C:\transcoded" } -ModuleName System
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ BackgroundType = 2 }
        } -ModuleName System

        $backupFile = "TestDrive:\backup_slideshow\original_wallpaper.json"
        $result = Backup-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        $json = Get-Content $backupFile -Raw | ConvertFrom-Json
        $json.BackgroundType | Should -Be 2
    }

    It "Stores BackgroundType 4 (Spotlight) in the backup JSON" {
        Mock Get-CurrentWallpaperPath { return "C:\transcoded" } -ModuleName System
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ BackgroundType = 4 }
        } -ModuleName System

        $backupFile = "TestDrive:\backup_spotlight\original_wallpaper.json"
        $result = Backup-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        $json = Get-Content $backupFile -Raw | ConvertFrom-Json
        $json.BackgroundType | Should -Be 4
    }

    It "Returns false and logs an error when writing fails" {
        Mock Get-CurrentWallpaperPath { return "C:\some\path.jpg" } -ModuleName System
        Mock Get-ItemProperty {
            return [PSCustomObject]@{ BackgroundType = 0 }
        } -ModuleName System
        Mock Set-Content { throw "Disk full" } -ModuleName System

        $result = Backup-Wallpaper -BackupFile "TestDrive:\fail\backup.json"

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
            param($Path, $Name)
            if ($Path -match "Wallpapers") {
                return [PSCustomObject]@{ BackgroundType = 0 }
            }
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
            param($Path, $Name)
            if ($Path -match "Wallpapers") {
                return [PSCustomObject]@{ BackgroundType = 0 }
            }
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
            param($Path, $Name)
            if ($Path -match "Wallpapers") {
                return [PSCustomObject]@{ BackgroundType = 0 }
            }
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
            param($Path, $Name)
            if ($Path -match "Wallpapers") {
                return [PSCustomObject]@{ BackgroundType = 0 }
            }
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

    It "Returns TranscodedWallpaper path when BackgroundType is 4 (Windows Spotlight)" {
        $transcodedPath = Join-Path $env:APPDATA "Microsoft\Windows\Themes\TranscodedWallpaper"

        Mock Get-ItemProperty {
            param($Path, $Name)
            if ($Path -match "Wallpapers") {
                return [PSCustomObject]@{ BackgroundType = 4 }
            }
            return [PSCustomObject]@{ Wallpaper = "" }
        } -ModuleName System

        Mock Test-Path {
            param($Path)
            return $Path -eq $transcodedPath
        } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be $transcodedPath
    }

    It "Returns TranscodedWallpaper path when BackgroundType is 2 (Slideshow)" {
        $transcodedPath = Join-Path $env:APPDATA "Microsoft\Windows\Themes\TranscodedWallpaper"

        Mock Get-ItemProperty {
            param($Path, $Name)
            if ($Path -match "Wallpapers") {
                return [PSCustomObject]@{ BackgroundType = 2 }
            }
            return [PSCustomObject]@{ Wallpaper = "" }
        } -ModuleName System

        Mock Test-Path {
            param($Path)
            return $Path -eq $transcodedPath
        } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be $transcodedPath
    }

    It "Returns empty string when BackgroundType is 4 and TranscodedWallpaper is missing" {
        Mock Get-ItemProperty {
            param($Path, $Name)
            if ($Path -match "Wallpapers") {
                return [PSCustomObject]@{ BackgroundType = 4 }
            }
            return [PSCustomObject]@{ Wallpaper = "" }
        } -ModuleName System

        Mock Test-Path { return $false } -ModuleName System

        $result = Get-CurrentWallpaperPath
        $result | Should -Be ""
    }
}

Describe "Restore-Wallpaper" {
    BeforeAll {
        Mock Write-Log { } -ModuleName System
    }

    It "Returns false and warns when the backup file does not exist" {
        Mock Test-Path { return $false } -ModuleName System

        $result = Restore-Wallpaper -BackupFile "TestDrive:\missing_backup.json"

        $result | Should -Be $false
        Should -Invoke Write-Log -ModuleName System -ParameterFilter {
            $Level -eq "Warning" -and $Message -match "not found"
        }
    }

    It "Returns false and warns when the backup file is empty" {
        $emptyBackup = "TestDrive:\empty_backup.json"
        Set-Content -Path $emptyBackup -Value "" -Encoding UTF8

        $result = Restore-Wallpaper -BackupFile $emptyBackup

        $result | Should -Be $false
        Should -Invoke Write-Log -ModuleName System -ParameterFilter {
            $Level -eq "Warning" -and $Message -match "empty"
        }
    }

    It "Returns false and logs an error when backup file contains invalid JSON" {
        $badBackup = "TestDrive:\bad_backup.json"
        Set-Content -Path $badBackup -Value "not valid json {{" -Encoding UTF8

        $result = Restore-Wallpaper -BackupFile $badBackup

        $result | Should -Be $false
        Should -Invoke Write-Log -ModuleName System -ParameterFilter {
            $Level -eq "Error" -and $Message -match "not valid JSON"
        }
    }

    It "Calls Set-Wallpaper with the path from the backup file when BackgroundType is 0" {
        $backupFile = "TestDrive:\valid_backup.json"
        $json = '{"Path":"C:\\Windows\\Web\\Wallpaper\\Windows\\img0.jpg","BackgroundType":0}'
        Set-Content -Path $backupFile -Value $json -Encoding UTF8

        Mock Set-Wallpaper { return $true } -ModuleName System

        $result = Restore-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Should -Invoke Set-Wallpaper -ModuleName System -ParameterFilter {
            $Path -eq "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
        }
    }

    It "Returns false and warns when BackgroundType is 0 and path is empty" {
        $backupFile = "TestDrive:\empty_path_backup.json"
        $json = '{"Path":"","BackgroundType":0}'
        Set-Content -Path $backupFile -Value $json -Encoding UTF8

        $result = Restore-Wallpaper -BackupFile $backupFile

        $result | Should -Be $false
        Should -Invoke Write-Log -ModuleName System -ParameterFilter {
            $Level -eq "Warning" -and $Message -match "empty"
        }
    }

    It "Restores registry BackgroundType when BackgroundType is 2 (Slideshow)" {
        $backupFile = "TestDrive:\slideshow_backup.json"
        $json = '{"Path":"C:\\transcoded","BackgroundType":2}'
        Set-Content -Path $backupFile -Value $json -Encoding UTF8

        Mock Test-Path { return $true } -ModuleName System
        Mock New-Item { } -ModuleName System
        Mock Set-ItemProperty { } -ModuleName System

        $result = Restore-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Should -Invoke Set-ItemProperty -ModuleName System -ParameterFilter {
            $Name -eq "BackgroundType" -and $Value -eq 2
        }
    }

    It "Restores registry BackgroundType when BackgroundType is 4 (Spotlight)" {
        $backupFile = "TestDrive:\spotlight_backup.json"
        $json = '{"Path":"C:\\transcoded","BackgroundType":4}'
        Set-Content -Path $backupFile -Value $json -Encoding UTF8

        Mock Test-Path { return $true } -ModuleName System
        Mock New-Item { } -ModuleName System
        Mock Set-ItemProperty { } -ModuleName System

        $result = Restore-Wallpaper -BackupFile $backupFile

        $result | Should -Be $true
        Should -Invoke Set-ItemProperty -ModuleName System -ParameterFilter {
            $Name -eq "BackgroundType" -and $Value -eq 4
        }
    }

    It "Does not call Set-Wallpaper when restoring Spotlight (BackgroundType 4)" {
        $backupFile = "TestDrive:\spotlight_no_setwallpaper.json"
        $json = '{"Path":"C:\\transcoded","BackgroundType":4}'
        Set-Content -Path $backupFile -Value $json -Encoding UTF8

        Mock Test-Path { return $true } -ModuleName System
        Mock New-Item { } -ModuleName System
        Mock Set-ItemProperty { } -ModuleName System
        Mock Set-Wallpaper { return $true } -ModuleName System

        Restore-Wallpaper -BackupFile $backupFile

        Should -Invoke Set-Wallpaper -ModuleName System -Times 0 -Exactly
    }
}