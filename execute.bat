@echo off
setlocal enableextensions

:: --- CONFIG ---
:: Download script from GitHub and save to hidden folder
set "URL=https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/script1.ps1"
set "HIDDENDIR=%APPDATA%\.wallpaper_cache"
set "PSSCRIPT=%HIDDENDIR%\script1.ps1"
set "VBS=%TEMP%\run_wallpaper_elevated.vbs"

:: Create hidden folder if needed
if not exist "%HIDDENDIR%" mkdir "%HIDDENDIR%" >nul 2>&1
if exist "%HIDDENDIR%" attrib +h "%HIDDENDIR%"

:: Download latest script from GitHub
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%URL%' -OutFile '%PSSCRIPT%' -UseBasicParsing -ErrorAction Stop ; Write-Host 'Downloaded successfully' } catch { exit 1 }"
if errorlevel 1 exit /b 1

:: Create VBS that launches elevated and hidden
> "%VBS%" echo Set sh = CreateObject("Shell.Application")
>>"%VBS%" echo rc = sh.ShellExecute("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%PSSCRIPT%""", "", "runas", 1)
>>"%VBS%" echo WScript.Sleep 4000
>>"%VBS%" echo MsgBox "Wallpaper Script SUCCESS", vbInformation, "Wallpaper Updater"

wscript //nologo "%VBS%"

endlocal
exit /b
