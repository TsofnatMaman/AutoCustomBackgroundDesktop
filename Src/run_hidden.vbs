Set WshShell = CreateObject("WScript.Shell")
exitCode = WshShell.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""%APPDATA%\.wallpaper_countdown\Src\daily_run.ps1""", 0, True)
WScript.Quit exitCode