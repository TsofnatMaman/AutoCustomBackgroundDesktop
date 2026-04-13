function Get-BaseImage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [string]$LogFile
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Url)) { throw "URL is empty" }
        if ([string]::IsNullOrWhiteSpace($Path)) { throw "Path is empty" }

        # הורדת התמונה
        Invoke-WebRequest -Uri $Url -OutFile $Path -ErrorAction Stop
        return $true
    }
    catch {
        if ($LogFile) {
            $msg = "Download failed: $($_.Exception.Message)"
            Write-Log -Message $msg -Level "Error" -LogFile $LogFile
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

    try {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($Base)
        $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)

        $g.DrawImage($img, 0, 0, $img.Width, $img.Height)

        $font = New-Object System.Drawing.Font("Arial", 40, [System.Drawing.FontStyle]::Bold)
        $brush = [System.Drawing.Brushes]::White
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

        $rect = New-Object System.Drawing.RectangleF(0, 0, $img.Width, $img.Height)
        
        $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 0, 0, 0))
        $g.FillRectangle($shadowBrush, 0, ($img.Height/2 - 50), $img.Width, 100)

        $g.DrawString($Text, $font, $brush, $rect, $sf)

        $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Jpeg)

        $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    }
    catch {
        Write-Log -Message "Rendering failed: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
    }
}

Export-ModuleMember -Function Get-BaseImage, Export-CountdownImage