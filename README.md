# Daily Countdown Wallpaper for Windows

Automatically sets your Windows desktop wallpaper to a base image with a **countdown text** rendered on top, updating daily until a target date. The app runs silently in the background via Windows Task Scheduler.

---

## Features

- Downloads a fresh base image and config daily from your GitHub repository.
- Renders a customizable countdown text (with shadow and semi-transparent background) onto the image.
- Sets the rendered image as the Windows desktop wallpaper.
- Runs silently — no visible PowerShell window.
- Task Scheduler integration:
  - Daily at a configured time (default `00:30`).
  - At every user logon.
  - Starts when available (catches up if the PC was off).
  - Runs on battery.
- Modular architecture with full Pester test coverage.
- When the countdown reaches zero or below, the app displays an uninstall reminder.

---

## Requirements

- Windows 10 / 11
- PowerShell 5.1+ (or PowerShell 7 with Windows compatibility)
- .NET Framework (for `System.Drawing`)
- Internet access (for initial install and daily config/image sync from GitHub)

---

## Installation

1. Fork this repository, open new branch for each event and push your customizations (see [Configuration](#configuration) below).
2. Download or use `release/install.exe`.
3. Run `install.exe` as Administrator.

The installer will:
- Download the repository ZIP from GitHub into `%APPDATA%\.wallpaper_countdown`.
- Load `Src/config.json` and register a Windows Scheduled Task (`ChangeWallpaperEveryDay`) that runs `Src/daily_run.ps1` silently via `Src/run_hidden.vbs`.
- Run `daily_run.ps1` immediately so the wallpaper is updated right away.

---

## Configuration

Edit `Src/config.json` before pushing to GitHub (the installer will pick it up automatically, and the daily run will keep it in sync):

```json
{
  "system": {
    "taskName": "ChangeWallpaperEveryDay",
    "appFolder": ".wallpaper_countdown"
  },
  "github": {
    "username": "YourGitHubUsername",
    "repository": "YourRepoName",
    "branch": "main",
    "imagePath": "backgrounds/1.jpg"
  },
  "wallpaper": {
    "targetDate": "2026-12-31",
    "text": "...עוד {days} ימים",
    "time": "00:30"
  }
}
```

| Key | Description |
|---|---|
| `system.taskName` | Name of the Windows Scheduled Task. |
| `system.appFolder` | Folder name under `%APPDATA%` used for local storage. |
| `github.username` | Your GitHub username (owner of the fork). *Automatically updates when pushed* |
| `github.repository` | Repository name. *Automatically updates when pushed* |
| `github.branch` | Branch to pull config and image from. *Automatically updates when pushed*|
| `github.imagePath` | Relative path to the base wallpaper image in the repo. **Changes take effect on the next daily run.** |
| `wallpaper.targetDate` | The target countdown date (`YYYY-MM-DD`). |
| `wallpaper.text` | Text rendered on the wallpaper. Use `{days}` as a placeholder for the day count. |
| `wallpaper.time` | Daily trigger time for the Scheduled Task (`HH:mm`). |

> **Note:** GitHub Actions workflows automatically run on push:
> - `.github/workflows/auto-update-config.yml` keeps `Src/config.json` and `Src/install.ps1` aligned with the current GitHub context.
> - `.github/workflows/build-exe.yml` builds `install.exe` and `uninstall.exe`, then updates `release/*.exe`.

---

## How It Works

1. **Install** — `install.ps1` downloads the repo ZIP, extracts it to `%APPDATA%\.wallpaper_countdown`, registers the scheduled task, and runs the first daily update.
2. **Daily run** — `Src/daily_run.ps1` orchestrates each update:
   - Polls `Src/config.json` from GitHub to stay in sync with any config changes you push.
   - Downloads the latest base image from `github.imagePath`.
   - Computes the number of days remaining until `wallpaper.targetDate`.
   - If days remaining ≤ 0: prints a completion message prompting you to run `uninstall.exe`.
   - Otherwise: renders the countdown text onto the image using GDI+ (`System.Drawing`) and sets it as the desktop wallpaper via `SystemParametersInfo`.
3. **Silent execution** — `Src/run_hidden.vbs` launches `daily_run.ps1` via `wscript.exe` with window style `0` (hidden), so no console window appears.

### Module overview

| Module | Responsibility |
|---|---|
| `Src/Modules/Logging.psm1` | File-based structured logging (`Initialize-Logging`, `Write-Log`). |
| `Src/Modules/Config.psm1` | Reads and validates `config.json` (`Get-Config`). |
| `Src/Modules/Downloads.psm1` | Polls remote config and images from GitHub with cache-busting headers (`Get-RemoteBaseUrl`, `Poll-RemoteConfig`, `Poll-Img`). |
| `Src/Modules/Countdown.psm1` | Calculates days remaining and formats the display text (`Get-DaysRemaining`, `Get-DaysText`). |
| `Src/Modules/Image.psm1` | Renders text overlay onto the base image and saves a JPEG (`Export-CountdownImage`). |
| `Src/Modules/System.psm1` | Sets the desktop wallpaper via the Windows API (`Set-Wallpaper`). |

---

## Uninstallation

Run `uninstall.exe` (or `Src/uninstall.ps1`) as Administrator. The uninstaller will:
- Clear the desktop wallpaper (set to black / blank).
- Remove the Windows Scheduled Task.
- Delete the `%APPDATA%\.wallpaper_countdown` folder.

> If the countdown has already reached zero, the daily run will print a reminder with the path to `uninstall.exe`.

---

## Development

### Run tests

Install [Pester](https://pester.dev/) v5 and run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force

Invoke-Pester .\Tests
```

### Run tests with code coverage

```powershell
$config = New-PesterConfiguration

$config.Run.Path = ".\Tests"

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = ".\Src\Modules\*.psm1"

$config.CodeCoverage.OutputFormat = "JaCoCo"
$config.CodeCoverage.OutputPath = ".\coverage.xml"

Invoke-Pester -Configuration $config
```

### Generate HTML coverage report

```powershell
reportgenerator `
  -reports:coverage.xml `
  -targetdir:coverage-report `
  -sourcedirs:Src\Modules
```

### Build EXE

EXE files are built automatically on `push` events that modify `Src/install.ps1` by `.github/workflows/build-exe.yml`.

The workflow:
- builds `install.exe` and `uninstall.exe` on `windows-latest`.
- commits them into `release/install.exe` and `release/uninstall.exe`.
- uploads them as GitHub Actions artifacts (`exes-<branch>-<sha>`).

If you want to build locally, install the [ps2exe](https://github.com/MScholtes/PS2EXE) module, then:

```powershell
Invoke-ps2exe .\Src\install.ps1 .\install.exe `
   -noConsole `
   -requireAdmin `
   -iconFile .\Src\icons\install.ico `
   -title "Wallpaper Installer" `
   -description "Installs wallpaper automation"

Invoke-ps2exe .\Src\uninstall.ps1 .\uninstall.exe `
  -noConsole `
  -requireAdmin `
  -iconFile .\Src\icons\uninstall.ico `
  -title "Wallpaper Uninstaller" `
  -description "Uninstalls wallpaper automation"
```
