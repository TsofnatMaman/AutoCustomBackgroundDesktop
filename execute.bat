@echo off
setlocal enableextensions

:: --- CONFIG ---
:: Download script from GitHub and copy config to hidden folder
set "SCRIPTURL=https://raw.githubusercontent.com/TsofnatMaman/AutoCustomBackgroundDesktop/refactor/script1.ps1"
set "HIDDENDIR=%APPDATA%\.wallpaper_cache"
set "PSSCRIPT=%HIDDENDIR%\script1.ps1"
set "CONFIG=%HIDDENDIR%\config.json"
set "LOCALCONFIG=%~dp0config.json"
set "VBS=%TEMP%\run_wallpaper_elevated.vbs"

:: Create hidden folder if needed
if not exist "%HIDDENDIR%" mkdir "%HIDDENDIR%" >nul 2>&1
if exist "%HIDDENDIR%" attrib +h "%HIDDENDIR%"

:: Download script from GitHub
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%SCRIPTURL%' -OutFile '%PSSCRIPT%' -UseBasicParsing -ErrorAction Stop ; Write-Host 'Downloaded successfully' } catch { exit 1 }"
if errorlevel 1 exit /b 1

:: Copy config from local folder to hidden folder
if exist "%LOCALCONFIG%" (
    copy "%LOCALCONFIG%" "%CONFIG%" >nul 2>&1
    echo Config copied successfully
) else (
    echo ERROR: config.json not found in %~dp0
    exit /b 1
)

:: Create VBS that launches elevated and hidden
> "%VBS%" echo Set sh = CreateObject("Shell.Application")
>>"%VBS%" echo rc = sh.ShellExecute("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%PSSCRIPT%""", "", "runas", 1)
>>"%VBS%" echo WScript.Sleep 4000
>>"%VBS%" echo MsgBox "Wallpaper Script SUCCESS", vbInformation, "Wallpaper Updater"

wscript //nologo "%VBS%"

endlocal
exit /b
