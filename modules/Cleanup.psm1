function Uninstall-Project {
    param($Config, $AppDir)

    Unregister-ScheduledTask -TaskName $Config.app.taskName -Confirm:$false -ErrorAction SilentlyContinue

    if (Test-Path $AppDir) {
        Remove-Item $AppDir -Recurse -Force
    }
}

Export-ModuleMember -Function Uninstall-Project