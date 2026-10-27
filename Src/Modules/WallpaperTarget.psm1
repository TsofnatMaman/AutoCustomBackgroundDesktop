function Get-WallpaperTargets {
    param([object]$Config)

    $targets = [ordered]@{ desktop = $true; lockScreen = $false }
    if ($null -eq $Config -or $null -eq $Config.wallpaper) { return [pscustomobject]$targets }

    $wallpaper = $Config.wallpaper
    if ($null -ne $wallpaper.targets) {
        foreach ($name in @('desktop', 'lockScreen')) {
            $property = $wallpaper.targets.PSObject.Properties[$name]
            if ($null -eq $property -or $property.Value -isnot [bool]) {
                throw "wallpaper.targets.$name must be a boolean (true or false)."
            }
            $targets[$name] = $property.Value
        }
        if ($wallpaper.targets.PSObject.Properties.Name | Where-Object { $_ -notin @('desktop', 'lockScreen') }) {
            throw 'wallpaper.targets contains an unsupported target.'
        }
        return [pscustomobject]$targets
    }

    if ($null -ne $wallpaper.applyTo) {
        switch -CaseSensitive ([string]$wallpaper.applyTo) {
            'desktop' { }
            'lockScreen' { $targets.desktop = $false; $targets.lockScreen = $true }
            'both' { $targets.lockScreen = $true }
            default { throw "Invalid wallpaper.applyTo '$($wallpaper.applyTo)'." }
        }
    }
    return [pscustomobject]$targets
}
Export-ModuleMember -Function Get-WallpaperTargets
