Import-Module "./modules/Image.psm1" -Force

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