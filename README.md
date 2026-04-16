## for run the tests:
install Pester -RequiredVersion 5.0.0

```PS
Import-Module Pester -RequiredVersion 5.7.1 -Force

Invoke-Pester .\Tests

# With Coverage

$config = New-PesterConfiguration

$config.Run.Path = ".\Tests"

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = ".\Src\Modules\*.psm1"

$config.CodeCoverage.OutputFormat = "JaCoCo"
$config.CodeCoverage.OutputPath = ".\coverage.xml"

Invoke-Pester -Configuration $config

# HTML Report

reportgenerator `
  -reports:coverage.xml `
  -targetdir:coverage-report `
  -sourcedirs:Src\Modules
```

## for build exe in PS:
install ps2exe module

``` PS
Invoke-ps2exe .\install.ps1 .\install.exe `
   -noConsole `
   -requireAdmin `
   -iconFile .\icon.ico `
   -title "Wallpaper Installer" `
   -description "Installs wallpaper automation"
```
