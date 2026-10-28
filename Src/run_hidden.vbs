Set WshShell = CreateObject("WScript.Shell")
scriptPath = WshShell.ExpandEnvironmentStrings("%APPDATA%") & "\.wallpaper_countdown\Src\daily_run.ps1"
exitCode = WshShell.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & scriptPath & """", 0, True)
WScript.Quit exitCode
