# Real binary round-trip checks. The PS2EXE "-extract" mode does not
# execute the embedded installer or uninstaller and is safe on CI Windows VMs.
Describe 'Packaged EXE scripts exactly match the current checkout' {
    It 'contains the current installer and uninstaller source' {
        foreach ($item in @(
            @{ Exe = 'install.exe'; Source = 'install.ps1' },
            @{ Exe = 'uninstall.exe'; Source = 'uninstall.ps1' }
        )) {
            $binary = Join-Path $PSScriptRoot "..\release\$($item.Exe)"
            $source = Join-Path $PSScriptRoot "..\Src\$($item.Source)"
            $output = Join-Path $TestDrive "extracted-$($item.Source)"

            if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
                throw "Missing release executable: $binary"
            }
            $process = Start-Process -FilePath $binary -ArgumentList "-extract:$output" -PassThru
            try {
                if (-not $process.WaitForExit(20000)) {
                    $process.Kill()
                    throw "Timed out extracting embedded source from $binary"
                }
                if ($process.ExitCode -ne 0) {
                    throw "Embedded script extraction failed for $binary (exit code $($process.ExitCode))"
                }
            }
            finally {
                $process.Dispose()
            }
            if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
                throw "EXE did not create extracted script: $binary"
            }
            $actual = [System.IO.File]::ReadAllText($output)
            $expected = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $source).ProviderPath)
            $normalizedActual = $actual.TrimStart([char]0xFEFF).Replace([string][char]13 + [char]10, [string][char]10).TrimEnd()
            $normalizedExpected = $expected.TrimStart([char]0xFEFF).Replace([string][char]13 + [char]10, [string][char]10).TrimEnd()
            $normalizedActual | Should -BeExactly $normalizedExpected -Because "$($item.Exe) must package its own repository source"
        }
    }
}
