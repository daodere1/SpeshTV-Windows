param([string]$ReportPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$reports = foreach ($bundle in Get-ChildItem (Join-Path $PSScriptRoot 'build/app/outputs/bundle') -Recurse -Filter '*.aab') {
    $zip = [IO.Compression.ZipFile]::OpenRead($bundle.FullName)
    try {
        $entry = $zip.GetEntry('BUNDLE-METADATA/com.android.tools/r8.json')
        if (!$entry) { throw "R8 metadata missing from $($bundle.Name)" }
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $metadata = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        $dex = @($zip.Entries | Where-Object FullName -Match '\.dex$')
        [pscustomobject]@{
            bundle = $bundle.Name
            dexBytes = ($dex | Measure-Object Length -Sum).Sum
            optimizationPercent = [Math]::Round(100 - $metadata.stats.noOptimizationPercentage, 2)
            obfuscationPercent = [Math]::Round(100 - $metadata.stats.noObfuscationPercentage, 2)
            shrinkingPercent = [Math]::Round(100 - $metadata.stats.noShrinkingPercentage, 2)
            optimizedResourceShrinking = $metadata.resourceOptimization.isOptimizedShrinkingEnabled
            repackageClasses = $metadata.options.isRepackageClassesEnabled
            fullMode = !$metadata.options.isProGuardCompatibilityModeEnabled
            r8Version = $metadata.version
        }
    } finally { $zip.Dispose() }
}
if ($ReportPath) { @($reports) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8 }
$reports | Format-List
