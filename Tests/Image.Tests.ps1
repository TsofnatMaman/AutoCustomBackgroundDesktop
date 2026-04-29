Import-Module "$PSScriptRoot/../Src/Modules/Image.psm1" -Force

Describe "Export-CountdownImage" {
    BeforeAll {
        Mock Write-Log { } -ModuleName Image
    }
    
    Context "Input Validation" {
        It "Throws an error if the Base image path is empty" {
            $result = Export-CountdownImage -Base "" -Output "C:\out.jpg" -Text "Test"
            $result | Should -Be $false
        }

        It "Attempts to create the directory if it does not exist" {
            # 1. Define the mocks clearly for the "Image" module scope
            Mock Test-Path { 
                param($Path)
                if ($Path -match "missingDir") { return $false }
                return $true 
            } -ModuleName Image

            Mock New-Item { 
                # Return a dummy object so the script doesn't fail on Pipe to Out-Null
                return @{ Name = "DummyDir" } 
            } -ModuleName Image
            
            # 2. Call the function
            Export-CountdownImage -Base "valid.jpg" -Output "C:\missingDir\out.jpg" -Text "Hello"
            
            # 3. Assert the mock was called inside the "Image" module
            Should -Invoke -CommandName New-Item -ModuleName Image -Times 1 -ParameterFilter {
                $Path -match "missingDir"
            }
        }
    }

    Context "Image Processing Logic" {
        It "Returns false if the image file cannot be read" {
            # Instead of mocking ReadAllBytes, we provide a file that doesn't exist
            # and ensure Test-Path returns true to "trick" the first validation
            Mock Test-Path { return $true } -ModuleName Image
            
            $result = Export-CountdownImage -Base "C:\NonExistentFile.jpg" -Output "out.jpg" -Text "Test"
            $result | Should -Be $false
        }

        It "Successfully completes the try block when inputs are valid" {
            # Setup: Create a tiny real dummy image to satisfy the .NET calls
            $testRoot = (Get-PSDrive TestDrive).Root
            $dummyPath = Join-Path $testRoot "dummy_base.jpg"
            $outputPath = Join-Path $testRoot "output_test.jpg"
            
            $bmp = New-Object System.Drawing.Bitmap(10, 10)
            $bmp.Save($dummyPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $bmp.Dispose()

            # Ensure Test-Path finds our dummy
            Mock Test-Path { return $true } -ModuleName Image

            try {
                $result = Export-CountdownImage -Base $dummyPath -Output $outputPath -Text "Success"
                $result | Should -Be $true
                Test-Path $outputPath | Should -Be $true
            }
            finally {
                # Cleanup
                if (Test-Path $dummyPath) { Remove-Item $dummyPath -ErrorAction SilentlyContinue }
                if (Test-Path $outputPath) { Remove-Item $outputPath -ErrorAction SilentlyContinue }
            }
        }

        It "Keeps existing output if rendering fails" {
            $testRoot = (Get-PSDrive TestDrive).Root
            $badBase = Join-Path $testRoot "bad.jpg"
            $outputPath = Join-Path $testRoot "output.jpg"

            "not an image" | Set-Content -Path $badBase
            "old output" | Set-Content -Path $outputPath

            $result = Export-CountdownImage -Base $badBase -Output $outputPath -Text "New text"

            $result | Should -Be $false
            (Get-Content $outputPath -Raw) | Should -Match "old output"
        }
    }
}
