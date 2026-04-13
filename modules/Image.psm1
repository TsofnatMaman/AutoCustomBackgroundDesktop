Import-Module "./modules/Logging.psm1"

function Get-BaseImage {
    param(
        [string]$Url,
        [string]$Path,
        [string]$LogFile
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        throw "URL is empty"
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Path is empty"
    }

    try {
        $dir = Split-Path $Path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        Invoke-WebRequest -Uri $Url -OutFile $Path -ErrorAction Stop
        return $true
    }
    catch {
        if ($LogFile) {
            Write-Log -Message "Download failed: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        }
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

    $img = $null
    $bmp = $null
    $g   = $null

    try {
        if ([string]::IsNullOrWhiteSpace($Base) -or -not (Test-Path $Base)) {
            throw "Base image not found"
        }

        $outDir = Split-Path $Output -Parent
        if ($outDir -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        Add-Type -AssemblyName System.Drawing

        $img = [System.Drawing.Image]::FromFile($Base)
        $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
        $g   = [System.Drawing.Graphics]::FromImage($bmp)

        $g.DrawImage($img, 0, 0, $img.Width, $img.Height)

        $font  = New-Object System.Drawing.Font("Arial", 40, [System.Drawing.FontStyle]::Bold)
        $brush = [System.Drawing.Brushes]::White

        $rect = New-Object System.Drawing.RectangleF(0,0,$img.Width,$img.Height)

        $g.DrawString($Text, $font, $brush, $rect)

        $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Jpeg)

        return $true
    }
    catch {
        if ($LogFile) {
            Write-Log -Message "Rendering failed: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        }
        return $false
    }
    finally {
        if ($g) { $g.Dispose() }
        if ($bmp) { $bmp.Dispose() }
        if ($img) { $img.Dispose() }
    }
}

Export-ModuleMember -Function Get-BaseImage, Export-CountdownImage