function Get-WallpaperTarget {
    param([object]$Config)

    $target = 'desktop'
    if ($null -ne $Config -and $null -ne $Config.wallpaper -and
        $null -ne $Config.wallpaper.applyTo) {
        $target = [string]$Config.wallpaper.applyTo
    }

    if ($target -cnotin @('desktop', 'lockScreen', 'both')) {
        throw "Invalid wallpaper.applyTo '$target'. Expected desktop, lockScreen or both."
    }

    return $target
}
