$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$path = [Drawing.Drawing2D.GraphicsPath]::new()
$font = [Drawing.FontFamily]::new('Segoe UI')
try {
    $path.AddString('SpeshTV', $font, [int][Drawing.FontStyle]::Bold, 40,
        [Drawing.PointF]::new(96, 60), [Drawing.StringFormat]::GenericTypographic)
    $parts = [Collections.Generic.List[string]]::new()
    $points = $path.PathPoints
    $types = $path.PathTypes
    $culture = [Globalization.CultureInfo]::InvariantCulture
    function PointText($p) { $p.X.ToString('0.###', $culture) + ',' + $p.Y.ToString('0.###', $culture) }
    for ($i = 0; $i -lt $points.Length; $i++) {
        $type = $types[$i] -band 7
        switch ($type) {
            0 { $parts.Add('M' + (PointText $points[$i])) }
            1 { $parts.Add('L' + (PointText $points[$i])) }
            3 {
                $parts.Add('C' + (PointText $points[$i]) + ' ' +
                    (PointText $points[$i + 1]) + ' ' + (PointText $points[$i + 2]))
                $i += 2
            }
            default { throw 'Unsupported font outline segment.' }
        }
        if (($types[$i] -band 128) -ne 0) { $parts.Add('Z') }
    }
    $letters = $parts -join ' '
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="320dp" android:height="180dp"
    android:viewportWidth="320" android:viewportHeight="180">
    <path android:fillColor="#101416" android:pathData="M0,0 H320 V180 H0 Z"/>
    <path android:fillColor="#00000000" android:strokeColor="#56D9CC"
        android:strokeWidth="4" android:strokeLineCap="round" android:strokeLineJoin="round"
        android:pathData="M36,68 L76,68 Q81,68 81,73 L81,97 Q81,102 76,102 L36,102 Q31,102 31,97 L31,73 Q31,68 36,68 Z M46,58 L56,68 L66,58 M46,110 L66,110"/>
    <path android:fillColor="#F3F5F6" android:pathData="$letters"/>
</vector>
"@
    $target = Join-Path (Split-Path $PSScriptRoot -Parent) 'android/app/src/main/res/drawable/speshtv_tv_banner.xml'
    [IO.File]::WriteAllText($target, $xml, [Text.UTF8Encoding]::new($false))
} finally {
    $path.Dispose()
    $font.Dispose()
}
