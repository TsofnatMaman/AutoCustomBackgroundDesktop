$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$taskName = "ChangeWallpaperEveryDay"

Write-Host "Installing..."

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$projectRoot\main.ps1`""

$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force

Start-Process powershell.exe "-File `"$projectRoot\main.ps1`"" -Verb RunAs

Write-Host "Done."