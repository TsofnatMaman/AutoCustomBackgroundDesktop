Import-Module (Join-Path $PSScriptRoot "Logging.psm1")

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

        $separator = if ($Url.Contains("?")) { "&" } else { "?" }
        $cacheStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $downloadUrl = "$Url$separator" + "cb=$cacheStamp"
        $headers = @{
            "Cache-Control" = "no-cache, no-store, must-revalidate"
            "Pragma" = "no-cache"
            "Expires" = "0"
        }

        Write-Log -Message "Starting download from $Url" -Level "Info" -LogFile $LogFile
        Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $Path -ErrorAction Stop
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

    $ms = $null
    $image = $null
    $graphics = $null
    $font = $null
    $brushText = $null
    $brushShadow = $null
    $brushBg = $null

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

        Write-Log -Message "Loading base image into memory (MemoryStream)" -Level "Info" -LogFile $LogFile
        $bytes = [System.IO.File]::ReadAllBytes($Base)
        $ms = New-Object System.IO.MemoryStream(, $bytes)
        $image = [System.Drawing.Image]::FromStream($ms)

        Write-Log -Message "Image dimensions: $($image.Width)x$($image.Height)" -Level "Debug" -LogFile $LogFile

        Write-Log -Message "Creating graphics context with rendering hints" -Level "Debug" -LogFile $LogFile
        $graphics = [System.Drawing.Graphics]::FromImage($image)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        Write-Log -Message "Setting up font with Hebrew fallback" -Level "Debug" -LogFile $LogFile
        try {
            $fontFamily = New-Object System.Drawing.FontFamily("David")
        } catch {
            Write-Log -Message "David font unavailable, falling back to Arial" -Level "Warning" -LogFile $LogFile
            $fontFamily = New-Object System.Drawing.FontFamily("Arial")
        }
        $fontSize = 72
        $font = New-Object System.Drawing.Font($fontFamily, $fontSize, [System.Drawing.FontStyle]::Bold)

        Write-Log -Message "Creating brushes (text, shadow, background)" -Level "Debug" -LogFile $LogFile
        $brushText = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $brushShadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 0, 0, 0))
        $brushBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 0, 0, 0))

        $stringFormat = New-Object System.Drawing.StringFormat
        $stringFormat.Alignment = [System.Drawing.StringAlignment]::Center
        $stringFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

        Write-Log -Message "Measuring text size" -Level "Debug" -LogFile $LogFile
        $textSize = $graphics.MeasureString($Text, $font)

        $cx = [single]($image.Width / 2.0)
        $cy = [single]($image.Height / 2.0)
        $halfTextW = [single]($textSize.Width / 2.0)
        $halfTextH = [single]($textSize.Height / 2.0)

        $padding = [single]30
        $shadowOffsetX = [single]4
        $shadowOffsetY = [single]4

        $rectX = [single]($cx - $halfTextW - $padding)
        $rectY = [single]($cy - $halfTextH - $padding)
        $rectWidth = [single]($textSize.Width + ($padding * 2))
        $rectHeight = [single]($textSize.Height + ($padding * 2))

        Write-Log -Message "Drawing background rectangle" -Level "Debug" -LogFile $LogFile
        [void]$graphics.FillRectangle($brushBg, $rectX, $rectY, $rectWidth, $rectHeight)

        $shadowPoint = New-Object System.Drawing.PointF(([single]($cx + $shadowOffsetX)), ([single]($cy + $shadowOffsetY)))
        Write-Log -Message "Drawing shadow text" -Level "Debug" -LogFile $LogFile
        [void]$graphics.DrawString($Text, $font, $brushShadow, $shadowPoint, $stringFormat)

        $point = New-Object System.Drawing.PointF($cx, $cy)
        Write-Log -Message "Drawing main text" -Level "Info" -LogFile $LogFile
        [void]$graphics.DrawString($Text, $font, $brushText, $point, $stringFormat)

        Write-Log -Message "Setting up JPEG encoder with quality 95" -Level "Debug" -LogFile $LogFile
        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
        $qualityEncoder = [System.Drawing.Imaging.Encoder]::Quality
        $encParam = New-Object System.Drawing.Imaging.EncoderParameter($qualityEncoder, 95L)
        $encParams.Param[0] = $encParam

        Write-Log -Message "Saving output image -> $Output" -Level "Info" -LogFile $LogFile
        $image.Save($Output, $jpegCodec, $encParams)

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

        if ($brushBg) { $brushBg.Dispose(); Write-Log -Message "Background brush disposed" -Level "Debug" -LogFile $LogFile }
        if ($brushShadow) { $brushShadow.Dispose(); Write-Log -Message "Shadow brush disposed" -Level "Debug" -LogFile $LogFile }
        if ($brushText) { $brushText.Dispose(); Write-Log -Message "Text brush disposed" -Level "Debug" -LogFile $LogFile }
        if ($font) { $font.Dispose(); Write-Log -Message "Font disposed" -Level "Debug" -LogFile $LogFile }
        if ($graphics) { $graphics.Dispose(); Write-Log -Message "Graphics disposed" -Level "Debug" -LogFile $LogFile }
        if ($image) { $image.Dispose(); Write-Log -Message "Image disposed" -Level "Debug" -LogFile $LogFile }
        if ($ms) { $ms.Dispose(); Write-Log -Message "MemoryStream disposed" -Level "Debug" -LogFile $LogFile }

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
        Set-Wallpaper -Path $finalImgPath -LogFile $LogFile

        Write-Log -Message "Wallpaper updated successfully." -LogFile $LogFile
    }
}

Export-ModuleMember -Function Get-BaseImage, Export-CountdownImage, Build-ImageUrl, Update-WallpaperFlow
