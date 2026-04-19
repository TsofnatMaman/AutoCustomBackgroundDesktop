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