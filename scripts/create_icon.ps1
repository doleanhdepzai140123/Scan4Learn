# Draw the app's geometric scan/book mark; no external graphics dependency.
Add-Type -AssemblyName System.Drawing
$assetDirectory = Join-Path $PSScriptRoot '../Scan4Learn/Assets.xcassets/AppIcon.appiconset'
$bitmap = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(23, 59, 48))
$lime = [System.Drawing.Color]::FromArgb(209, 242, 122)
$pen = New-Object System.Drawing.Pen($lime, 36)
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(247, 248, 236), 28)
$whitePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$whitePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$whitePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
try {
    $graphics.DrawLines($pen, [System.Drawing.Point[]]@([System.Drawing.Point]::new(210,350), [System.Drawing.Point]::new(210,210), [System.Drawing.Point]::new(350,210)))
    $graphics.DrawLines($pen, [System.Drawing.Point[]]@([System.Drawing.Point]::new(674,210), [System.Drawing.Point]::new(814,210), [System.Drawing.Point]::new(814,350)))
    $graphics.DrawLines($pen, [System.Drawing.Point[]]@([System.Drawing.Point]::new(814,674), [System.Drawing.Point]::new(814,814), [System.Drawing.Point]::new(674,814)))
    $graphics.DrawLines($pen, [System.Drawing.Point[]]@([System.Drawing.Point]::new(350,814), [System.Drawing.Point]::new(210,814), [System.Drawing.Point]::new(210,674)))
    $graphics.DrawLines($whitePen, [System.Drawing.Point[]]@([System.Drawing.Point]::new(320,360), [System.Drawing.Point]::new(512,406), [System.Drawing.Point]::new(704,360), [System.Drawing.Point]::new(704,650), [System.Drawing.Point]::new(512,696), [System.Drawing.Point]::new(320,650), [System.Drawing.Point]::new(320,360)))
    $graphics.DrawLine($whitePen, 512, 406, 512, 696)
    $graphics.DrawLine($pen, 376, 468, 444, 484)
    $graphics.DrawLine($pen, 376, 548, 444, 564)
    $graphics.DrawLine($pen, 580, 484, 648, 468)
    $graphics.DrawLine($pen, 580, 564, 648, 548)
    $bitmap.Save((Join-Path $assetDirectory 'AppIcon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $whitePen.Dispose()
    $pen.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}
