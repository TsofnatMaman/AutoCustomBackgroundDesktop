Import-Module "./modules/Image.psm1"
Import-Module "./modules/Logging.psm1"

Describe "Image Module" {

    BeforeAll {
        $testDir = (New-Item "$env:TEMP\ImageTests" -ItemType Directory -Force).FullName

        $BaseImagePath = Join-Path $testDir "base.jpg"
        $OutputPath    = Join-Path $testDir "out.jpg"
        $LogPath       = Join-Path $testDir "log.txt"

        Mock Write-Log -ModuleName Image
    }

    AfterAll {
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context "Get-BaseImage" {

        It "downloads image successfully" {
            $r = Get-BaseImage -Url "https://www.google.com/favicon.ico" -Path $BaseImagePath -LogFile $LogPath
            $r | Should -BeTrue
            Test-Path $BaseImagePath | Should -BeTrue
        }

        It "returns false and logs error on failure" {
            $r = Get-BaseImage -Url "https://invalid.example/none.jpg" -Path $BaseImagePath -LogFile $LogPath
            $r | Should -BeFalse

            Assert-MockCalled Write-Log -ModuleName Image -Times 1
        }

        It "throws on empty URL" {
            { Get-BaseImage -Url $null -Path $BaseImagePath } |
                Should -Throw "URL is empty"
        }
    }

    Context "Export-CountdownImage" {

        It "creates image successfully" {

            if (-not (Test-Path $BaseImagePath)) {
                $bmp = New-Object System.Drawing.Bitmap(100,100)
                $bmp.Save($BaseImagePath)
                $bmp.Dispose()
            }

            $r = Export-CountdownImage -Base $BaseImagePath -Output $OutputPath -Text "Hello" -LogFile $LogPath

            $r | Should -BeTrue
            Test-Path $OutputPath | Should -BeTrue
        }

        It "logs failure when base image missing" {

            $r = Export-CountdownImage -Base "C:\missing.jpg" -Output $OutputPath -Text "x" -LogFile $LogPath
            $r | Should -BeFalse

            Assert-MockCalled Write-Log -ModuleName Image -Times 1
        }
    }
}

Describe "Build-ImageUrl Tests" {
    It "Should correctly format the GitHub raw URL" {
        $mockCfg = @{
            github = @{
                username   = "User123"
                repository = "MyRepo"
                branch     = "main"
                imagePath  = "assets/bg.jpg"
            }
        }
        
        $expected = "https://raw.githubusercontent.com/User123/MyRepo/main/assets/bg.jpg"
        $result = Build-ImageUrl -cfg $mockCfg
        
        $result | Should -BeExactly $expected
    }
}

Describe "Update-WallpaperFlow Tests" {
    
    BeforeEach {
        $script:AppDir = "C:\MockDir"
        $script:LogFile = "C:\MockDir\log.txt"
        $script:daysRemaining = 5
        
        $script:mockCfg = @{
            wallpaper = @{ text = "Only {days} days left!" }
            github    = @{ 
                username = "test"; repository = "test"; branch = "main"; imagePath = "img.jpg" 
            }
        }

        Mock Write-Log {} -ModuleName Image
        Mock Get-BaseImage { return $true } -ModuleName Image
        Mock Export-CountdownImage {} -ModuleName Image
        Mock Set-Wallpaper {} -ModuleName Image
    }

    It "Should process the text and call wallpaper update" {
        {
            Update-WallpaperFlow -cfg $script:mockCfg -AppDir $script:AppDir -LogFile $script:LogFile -daysRemaining $script:daysRemaining
        } | Should -Not -Throw
        
        Assert-MockCalled Export-CountdownImage -ModuleName Image -ParameterFilter {
            $null -ne $Base -and $null -ne $Output -and $Text -eq "Only 5 days left!"
        }
    }
}