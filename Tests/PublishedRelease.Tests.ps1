# Validate the real main-branch artifacts that users download, not just
# build logs or the current test branch. All work happens in TestDrive.
Describe 'Published main installer artifacts' {
    It 'embeds the exact PowerShell installer and uninstaller currently published on main' {
        $baseUrl = 'https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/main'
        foreach ($name in @('install', 'uninstall')) {
            $exe = Join-Path $TestDrive "$name-main.exe"
            $src = Join-Path $TestDrive "$name-main.ps1"
            $extracted = Join-Path $TestDrive "$name-main-extracted.ps1"
            Invoke-WebRequest -Uri "$baseUrl/release/$name.exe" -OutFile $exe -UseBasicParsing -TimeoutSec 45 -ErrorAction Stop
            Invoke-WebRequest -Uri "$baseUrl/Src/$name.ps1" -OutFile $src -UseBasicParsing -TimeoutSec 45 -ErrorAction Stop

            $process = Start-Process -FilePath $exe -ArgumentList "-extract:$extracted" -PassThru
            try {
                if (-not $process.WaitForExit(20000)) { $process.Kill(); throw "EXE script extraction timed out: $name" }
                if ($process.ExitCode -ne 0) { throw "EXE script extraction failed: $name" }
            }
            finally { $process.Dispose() }

            (Test-Path -LiteralPath $extracted -PathType Leaf) | Should -BeTrue
            $actual = [System.IO.File]::ReadAllText($extracted).TrimStart([char]0xFEFF).Replace([string][char]13 + [char]10,[string][char]10).TrimEnd()
            $expected = [System.IO.File]::ReadAllText($src).TrimStart([char]0xFEFF).Replace([string][char]13 + [char]10,[string][char]10).TrimEnd()
            $actual | Should -BeExactly $expected -Because "published main/$name.exe must match main/Src/$name.ps1"
        }
    }

    It 'serves a complete installation archive with all required runtime files' {
        $archive = Join-Path $TestDrive 'main.zip'
        $dest = Join-Path $TestDrive 'main-archive'
        Invoke-WebRequest -Uri 'https://github.com/TsofnatMaman/AutoCustomBackgroundDesktop/archive/refs/heads/main.zip' -OutFile $archive -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
        Expand-Archive -LiteralPath $archive -DestinationPath $dest -Force
        $repoDir = Get-ChildItem -LiteralPath $dest -Directory | Select-Object -First 1
        if (-not $repoDir) { throw 'GitHub archive did not contain a repository folder' }

        foreach ($required in @(
            'Src\install.ps1',
            'Src\uninstall.ps1',
            'Src\daily_run.ps1',
            'Src\run_hidden.vbs',
            'Src\config.json',
            'Src\Modules\Config.psm1',
            'Src\Modules\Downloads.psm1',
            'Src\Modules\Image.psm1',
            'Src\Modules\System.psm1',
            'backgrounds\1.jpg'
        )) {
            (Test-Path -LiteralPath (Join-Path $repoDir.FullName $required) -PathType Leaf) |
                Should -BeTrue -Because "the release installer requires $required"
        }
    }
}
