@echo off
setlocal enableextensions

:: --- CONFIG ---
:: Use local script from same directory
set "PSSCRIPT=%~dp0script1.ps1"
set "VBS=%TEMP%\run_wallpaper_elevated.vbs"

if not exist "%PSSCRIPT%" (
    echo ERROR: script1.ps1 not found in current directory
    exit /b 1
)

:: Create one-shot VBS that launches elevated & hidden
> "%VBS%" echo Set sh = CreateObject("Shell.Application")
>>"%VBS%" echo rc = sh.ShellExecute("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%PSSCRIPT%""", "", "runas", 1)
>>"%VBS%" echo WScript.Sleep 4000
>>"%VBS%" echo MsgBox "Wallpaper Script SUCCESS", vbInformation, "Wallpaper Updater"

wscript //nologo "%VBS%"

endlocal
exit /b
