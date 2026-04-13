function Get-BaseImage {
    param([string]$RemoteImageUrl, [string]$BaseImagePath)

    Write-Log "Downloading image..."

    $tempPath = $BaseImagePath + ".new"
    $cacheBust = [Uri]::EscapeDataString((Get-Date).ToString("yyyyMMddHHmmss"))
    $downloadUri = "$RemoteImageUrl?ts=$cacheBust"

    try {
        Invoke-WebRequest -Uri $downloadUri -OutFile $tempPath -TimeoutSec 15 -ErrorAction Stop

        if ((Test-Path $tempPath) -and ((Get-Item $tempPath).Length -gt 0)) {
            Move-Item $tempPath $BaseImagePath -Force
            return $true
        }

        throw "Invalid image"
    }
    catch {
        Write-Log "Download failed." -Level Warning
        return Test-Path $BaseImagePath
    }
}

function Export-CountdownImage {
    param($BaseImagePath, $FinalImagePath, $Text)

    $img = [System.Drawing.Image]::FromFile($BaseImagePath)
    $g = [System.Drawing.Graphics]::FromImage($img)

    $font = New-Object System.Drawing.Font("Arial", 72, [System.Drawing.FontStyle]::Bold)
    $brush = [System.Drawing.Brushes]::White

    $g.DrawString($Text, $font, $brush, 100, 100)

    $img.Save($FinalImagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

    $g.Dispose()
    $img.Dispose()
}

Export-ModuleMember -Function Get-BaseImage, Export-CountdownImage