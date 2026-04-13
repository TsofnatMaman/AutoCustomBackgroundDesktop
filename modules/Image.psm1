function Get-BaseImage {
    param([string]$RemoteImageUrl, [string]$BaseImagePath)

    Write-Log "Syncing background image..."
    $tempPath = $BaseImagePath + ".new"
    $cacheBust = [Uri]::EscapeDataString((Get-Date).ToString("yyyyMMddHHmmss"))
    $downloadUri = if ($RemoteImageUrl -match '\?') { "$RemoteImageUrl&ts=$cacheBust" } else { "$RemoteImageUrl?ts=$cacheBust" }

    try {
        Invoke-WebRequest -Uri $downloadUri -OutFile $tempPath -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop

        if ((Test-Path $tempPath) -and ((Get-Item $tempPath).Length -gt 0)) {
            if (Test-Path $BaseImagePath) { Remove-Item $BaseImagePath -Force }
            Move-Item -Path $tempPath -Destination $BaseImagePath -Force
            Write-Log "Image successfully updated from remote source."
            return $true
        } else {
            throw "Downloaded file validation failed."
        }
    }
    catch {
        Write-Log "Download failed ($($_.Exception.Message)). Reverting to local cache." -Level Warning
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force -ErrorAction SilentlyContinue }
        return Test-Path $BaseImagePath
    }
}

function Export-CountdownImage {
    param([string]$BaseImagePath, [string]$FinalImagePath, [string]$Text)

    $bytes = [System.IO.File]::ReadAllBytes($BaseImagePath)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $image = [System.Drawing.Image]::FromStream($ms)
    $graphics = [System.Drawing.Graphics]::FromImage($image)

    $font = New-Object System.Drawing.Font("Arial", 72, [System.Drawing.FontStyle]::Bold)
    $brush = [System.Drawing.Brushes]::White

    $graphics.DrawString($Text, $font, $brush, 100, 100)

    $image.Save($FinalImagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

    $graphics.Dispose()
    $image.Dispose()
    $ms.Dispose()
}

Export-ModuleMember -Function Get-BaseImage, Export-CountdownImage