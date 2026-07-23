# Resize raw guide screenshots (build/guide_shots) to 540px wide PNGs in docs/img
Add-Type -AssemblyName System.Drawing
$src = 'c:\Dev\ReefTracker\build\guide_shots'
$dst = 'c:\Dev\ReefTracker\docs\img'
New-Item -ItemType Directory -Force $dst | Out-Null
Get-ChildItem "$src\*.png" | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $w = 540
    $h = [int]([math]::Round($img.Height * ($w / $img.Width)))
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $w, $h)
    $out = Join-Path $dst $_.Name
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    $kb = [math]::Round((Get-Item $out).Length / 1kb)
    Write-Output "$($_.Name) -> ${w}x${h} (${kb} KB)"
}
