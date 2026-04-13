# Daily Countdown Wallpaper for Windows

This project provides a PowerShell script (with an optional batch bootstrapper) that automatically downloads a base image, renders a **countdown text** until a target date, and sets it as the Windows desktop wallpaper.  
It also installs a **scheduled task** so that the wallpaper is updated **silently** every day and at user logon.

---

## Features

- Downloads a fresh base image daily from GitHub.
- Draws centered text with shadow and background (e.g., “X days left…”).
- Updates the Windows wallpaper automatically.
- Runs silently in the background (no visible PowerShell window).
- Task Scheduler integration:
  - Daily at a chosen time (default `00:30`).
  - At logon.
- Supports fallback if download fails (uses last cached image).

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

- **Target date** is currently set to **2025-05-15** inside `script1.ps1`:

  ```powershell
  $targetDay = Get-Date "2025-05-15"
  ```

  Change this line to your desired date.

- **Scheduled time** defaults to `00:30`:

  ```powershell
  $dailyTime = "00:30"
  ```

  Update this to another time if needed.

- **Base image URL** can be replaced with your own image source.

---

## How It Works

1. **Download** – Grabs the base image daily with cache-busting.  
2. **Render** – Draws countdown text with font, shadow, and semi-transparent background.  
3. **Set wallpaper** – Calls Windows API (`SystemParametersInfo`) to apply the image.  
4. **Silent updates** – A VBScript launcher is created, and Task Scheduler runs it daily and at logon, hidden from the user.

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
Invoke-Pester .\Tests
```

## for uninstall run from **adminitrator PS**

```PS
uninstall.ps1
```