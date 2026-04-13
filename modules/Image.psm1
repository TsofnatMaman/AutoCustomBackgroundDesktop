Import-Module "./modules/Logging.psm1"

function Get-BaseImage {
    param(
        [string]$Url,
        [string]$Path,
        [string]$LogFile
    )

    Write-Log -Message "=== Get-BaseImage START ===" -Level "Info" -LogFile $LogFile
    Write-Log -Message "Input Url: $Url" -Level "Debug" -LogFile $LogFile
    Write-Log -Message "Target Path: $Path" -Level "Debug" -LogFile $LogFile

    if ([string]::IsNullOrWhiteSpace($Url)) {
        Write-Log -Message "URL validation failed (empty)" -Level "Error" -LogFile $LogFile
        throw "URL is empty"
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Log -Message "Path validation failed (empty)" -Level "Error" -LogFile $LogFile
        throw "Path is empty"
    }

    try {
        $dir = Split-Path $Path -Parent
        Write-Log -Message "Resolved directory: $dir" -Level "Debug" -LogFile $LogFile

        if ($dir -and -not (Test-Path $dir)) {
            Write-Log -Message "Directory does not exist. Creating..." -Level "Info" -LogFile $LogFile
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log -Message "Directory created successfully" -Level "Info" -LogFile $LogFile
        }
        else {
            Write-Log -Message "Directory already exists" -Level "Debug" -LogFile $LogFile
        }

        Write-Log -Message "Starting download from $Url" -Level "Info" -LogFile $LogFile
        Invoke-WebRequest -Uri $Url -OutFile $Path -ErrorAction Stop
        Write-Log -Message "Download completed successfully -> $Path" -Level "Info" -LogFile $LogFile

        Write-Log -Message "=== Get-BaseImage SUCCESS ===" -Level "Info" -LogFile $LogFile
        return $true
    }
    catch {
        Write-Log -Message "Download failed: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        Write-Log -Message "=== Get-BaseImage FAILED ===" -Level "Error" -LogFile $LogFile
        return $false
    }
}

function Export-CountdownImage {
    param(
        [string]$Base,
        [string]$Output,
        [string]$Text,
        [string]$LogFile
    )

    Write-Log -Message "=== Export-CountdownImage START ===" -Level "Info" -LogFile $LogFile
    Write-Log -Message "Base Image: $Base" -Level "Debug" -LogFile $LogFile
    Write-Log -Message "Output Path: $Output" -Level "Debug" -LogFile $LogFile
    Write-Log -Message "Text: $Text" -Level "Debug" -LogFile $LogFile

    $img = $null
    $bmp = $null
    $g   = $null

    try {
        if ([string]::IsNullOrWhiteSpace($Base) -or -not (Test-Path $Base)) {
            Write-Log -Message "Base image validation failed" -Level "Error" -LogFile $LogFile
            throw "Base image not found"
        }

        $outDir = Split-Path $Output -Parent
        Write-Log -Message "Resolved output directory: $outDir" -Level "Debug" -LogFile $LogFile

        if ($outDir -and -not (Test-Path $outDir)) {
            Write-Log -Message "Output directory missing. Creating..." -Level "Info" -LogFile $LogFile
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            Write-Log -Message "Output directory created" -Level "Info" -LogFile $LogFile
        }

        Write-Log -Message "Loading System.Drawing assembly" -Level "Debug" -LogFile $LogFile
        Add-Type -AssemblyName System.Drawing

        Write-Log -Message "Loading base image into memory" -Level "Info" -LogFile $LogFile
        $img = [System.Drawing.Image]::FromFile($Base)

        Write-Log -Message "Image dimensions: $($img.Width)x$($img.Height)" -Level "Debug" -LogFile $LogFile

        Write-Log -Message "Creating bitmap and graphics context" -Level "Debug" -LogFile $LogFile
        $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
        $g   = [System.Drawing.Graphics]::FromImage($bmp)

        Write-Log -Message "Drawing base image onto bitmap" -Level "Debug" -LogFile $LogFile
        $g.DrawImage($img, 0, 0, $img.Width, $img.Height)

        Write-Log -Message "Preparing font and brush" -Level "Debug" -LogFile $LogFile
        $font  = New-Object System.Drawing.Font("Arial", 40, [System.Drawing.FontStyle]::Bold)
        $brush = [System.Drawing.Brushes]::White

        $rect = New-Object System.Drawing.RectangleF(0,0,$img.Width,$img.Height)
        Write-Log -Message "Drawing text onto image" -Level "Info" -LogFile $LogFile

        $g.DrawString($Text, $font, $brush, $rect)

        Write-Log -Message "Saving output image -> $Output" -Level "Info" -LogFile $LogFile
        $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Jpeg)

        Write-Log -Message "Image saved successfully" -Level "Info" -LogFile $LogFile
        Write-Log -Message "=== Export-CountdownImage SUCCESS ===" -Level "Info" -LogFile $LogFile

        return $true
    }
    catch {
        Write-Log -Message "Rendering failed: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        Write-Log -Message "=== Export-CountdownImage FAILED ===" -Level "Error" -LogFile $LogFile
        return $false
    }
    finally {
        Write-Log -Message "Cleaning up resources" -Level "Debug" -LogFile $LogFile

        if ($g) { $g.Dispose(); Write-Log -Message "Graphics disposed" -Level "Debug" -LogFile $LogFile }
        if ($bmp) { $bmp.Dispose(); Write-Log -Message "Bitmap disposed" -Level "Debug" -LogFile $LogFile }
        if ($img) { $img.Dispose(); Write-Log -Message "Image disposed" -Level "Debug" -LogFile $LogFile }

        Write-Log -Message "=== Export-CountdownImage END ===" -Level "Info" -LogFile $LogFile
    }
}

function Build-ImageUrl {
    param($cfg)

    return "https://raw.githubusercontent.com/$($cfg.github.username)/$($cfg.github.repository)/$($cfg.github.branch)/$($cfg.github.imagePath)"
}

function Update-WallpaperFlow {
    param($cfg, $AppDir, $LogFile, $daysRemaining)

    $baseImgPath = Join-Path $AppDir "base.jpg"
    $finalImgPath = Join-Path $AppDir "wallpaper.jpg"

    $url = Build-ImageUrl $cfg
    Write-Log -Message "Fetching: $url" -LogFile $LogFile

    if (Get-BaseImage -Url $url -Path $baseImgPath -LogFile $LogFile) {
        $msgText = $cfg.wallpaper.text.Replace("{days}", $daysRemaining)

        Export-CountdownImage -Base $baseImgPath -Output $finalImgPath -Text $msgText -LogFile $LogFile
        Set-Wallpaper -Path $finalImgPath

        Write-Log -Message "Wallpaper updated successfully." -LogFile $LogFile
    }
}

Export-ModuleMember -Function Get-BaseImage, Export-CountdownImage, Build-ImageUrl, Update-WallpaperFlow