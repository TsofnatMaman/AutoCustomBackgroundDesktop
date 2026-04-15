# Daily Countdown Wallpaper for Windows

This project provides a PowerShell script (with an optional batch bootstrapper) that automatically downloads a base image, renders a **countdown text** until a target date, and sets it as the Windows desktop wallpaper.  
It also installs a **scheduled task** so that the wallpaper is updated **silently** every day and at user logon.

---

## Features

- **Downloads fresh config daily from GitHub** – Always gets the latest settings.
- Downloads a fresh base image daily from GitHub based on the config path.
- Draws centered text with shadow and background (e.g., "X days left…").
- Updates the Windows wallpaper automatically.
- Runs silently in the background (no visible PowerShell window).
- Task Scheduler integration:
  - Daily at a chosen time (default `09:00`).
  - At logon.
- Supports fallback if download fails (uses cached config/image if available).

---

## Files

- **`script1.ps1`**  
  Main PowerShell script: handles image download, rendering, wallpaper update, and scheduled task creation (with hidden VBScript launcher).

- **`run_wallpaper_silent.vbs`** (generated automatically)  
  Tiny VBScript used to launch the PowerShell script silently.

- **`bootstrap.bat`**  
  Batch file that downloads the latest `script1.ps1` from GitHub into `%APPDATA%\Microsoft\Windows\` and executes it.

---

## Installation

1. Clone or download this repository, or simply use the provided **batch bootstrapper**:

   ```bat
   @echo off
   set "psScript=%APPDATA%\Microsoft\Windows\script1.ps1"

   echo download...
   powershell -Command "Invoke-WebRequest -Uri https://raw.githubusercontent.com/<username>/<repo>/main/AutoCustomBackgroundDesktop/script1.ps1 -OutFile '%psScript%'"

   if exist "%psScript%" (
       echo success
       powershell -ExecutionPolicy Bypass -File "%psScript%"
   ) else (
       echo error
   )
   ```

   Replace `<username>/<repo>` with this repository path.

2. Run the batch file once.  
   - It will download and execute the PowerShell script.  
   - The script creates the VBScript launcher and registers the scheduled task.

---

## Configuration

The configuration is now **automatically downloaded from GitHub** on each run to:
```
%APPDATA%\.WallpaperProject\config.json
```

If the remote download fails, the script falls back to the local `config.json` in the project folder.

### Config File Structure

The `config.json` contains:

```json
{
    "app": {
        "name": "WallpaperProject",
        "taskName": "ChangeWallpaperEveryDay",
        "appFolder": ".wallpaper_cache",
        "logFilePattern": "wallpaper_{date}.log"
    },
    "github": {
        "username": "TsofnatMaman",
        "repository": "AutoCustomBackgroundDesktop",
        "branch": "refactor",
        "imagePath": "backgrounds/2.jpg"
    },
    "wallpaper": {
        "targetDate": "2126-04-20",
        "text": "...עוד {days} ימים",
        "time": "09:00"
    },
    "system": {
        "tempZipName": "wallpaper.zip",
        "mutexName": "WallpaperScriptLock"
    }
}
```

**To customize:**
- Edit the config in your GitHub repository.
- The script will automatically pull the new config on the next run.
- No need to redeploy or restart anything!

---

## How It Works

1. **Download config** – Fetches the latest `config.json` from GitHub to `%APPDATA%\.WallpaperProject\` each run.
2. **Parse config** – Reads the target date, image path, and countdown text from the config.
3. **Download image** – Fetches the base image daily from GitHub (path is defined in config: `github.imagePath`).
4. **Render** – Draws countdown text with font, shadow, and semi-transparent background.
5. **Set wallpaper** – Calls Windows API (`SystemParametersInfo`) to apply the image.
6. **Silent updates** – A VBScript launcher is created, and Task Scheduler runs it daily and at logon, hidden from the user.

### Config Download Flow

Each time the script runs:
```
main.ps1 executes
    ↓
Load-Configuration() called with remote URL
    ↓
Get-RemoteConfig() → Downloads config.json from GitHub
    ↓
Saves to: %APPDATA%\.WallpaperProject\config.json
    ↓
Fallback to local config if download fails
    ↓
Update-WallpaperFlow() → Uses config to download image and update wallpaper
```

---

## Requirements

- Windows 10 / 11  
- PowerShell 5+ (or PowerShell 7 with Windows compatibility)  
- .NET Framework (for `System.Drawing`)

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

**Note**: install.ps1 is now standalone (contains embedded functions, no external module dependencies), so the compiled EXE will work independently without needing to bundle modules.

## for run the tests:
install Pester -RequiredVersion 5.0.0
```PS
Import-Module Pester -RequiredVersion 5 -Force

Invoke-Pester .\Tests

 Invoke-Pester -Path .\Tests -CodeCoverage @(    
    '.\Src\*.ps1',
    '.\Src\Modules\*.psm1'
```

## for uninstall run from **adminitrator PS**

```PS
uninstall.ps1
```