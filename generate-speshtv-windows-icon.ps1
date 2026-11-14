$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$bitmap = New-Object Drawing.Bitmap 256, 256
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$pen = New-Object Drawing.Pen ([Drawing.ColorTranslator]::FromHtml('#56D9CC')), 4
$path = New-Object Drawing.Drawing2D.GraphicsPath
$stream = New-Object IO.MemoryStream
try {
    $graphics.Clear([Drawing.ColorTranslator]::FromHtml('#121416'))
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.ScaleTransform(256 / 108, 256 / 108)
    $pen.StartCap = $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    # Rasterize the existing Android STV foreground geometry into an ICO.
    $path.AddLine(34,39,74,39)
    $path.AddBezier(74,39,77.33,39,79,40.67,79,44)
    $path.AddLine(79,44,79,68)
    $path.AddBezier(79,68,79,71.33,77.33,73,74,73)
    $path.AddLine(74,73,34,73)
    $path.AddBezier(34,73,30.67,73,29,71.33,29,68)
    $path.AddLine(29,68,29,44)
    $path.AddBezier(29,44,29,40.67,30.67,39,34,39)
    $path.CloseFigure()
    $graphics.DrawPath($pen,$path)
    $graphics.DrawLine($pen,44,29,54,39)
    $graphics.DrawLine($pen,54,39,64,29)
    $graphics.DrawLine($pen,44,81,64,81)
    $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
    $output = Join-Path $PSScriptRoot 'windows/runner/resources/speshtv.ico'
    $writer = New-Object IO.BinaryWriter ([IO.File]::Create($output))
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
        $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$stream.Length); $writer.Write([uint32]22)
        $writer.Write($stream.ToArray())
    } finally { $writer.Dispose() }
} finally {
    $stream.Dispose(); $path.Dispose(); $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
