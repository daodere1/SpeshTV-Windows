param(
    [string]$WebRoot = 'C:\Program Files\Jellyfin\Server\jellyfin-web',
    [string]$ServerUrl = 'http://127.0.0.1:8097'
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../build/web')).Path
$web = (Resolve-Path -LiteralPath $WebRoot).Path
$root = [IO.Path]::GetFullPath((Join-Path $web 'speshtv-0.1.0'))
$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$live = Join-Path $root 'moonfin'
$stage = Join-Path $root "moonfin-stage-$stamp"
$backup = Join-Path $root "moonfin-backup-$stamp"
$failed = Join-Path $root "moonfin-failed-$stamp"

# Moonbase can update its own frontend without replacing this customized build.
foreach ($target in @($live, $stage, $backup, $failed)) {
    if (-not [IO.Path]::GetFullPath($target).StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Target outside SpeshTV directory: $target"
    }
}
for ($dir = Get-Item -LiteralPath $web; $null -ne $dir; $dir = $dir.Parent) {
    if ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing a linked installation path.' }
}
foreach ($path in @($root, $live)) {
    if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Refusing a linked SpeshTV directory.'
    }
}
if (Get-ChildItem -LiteralPath $source -Recurse -Attributes ReparsePoint) { throw 'Build contains linked files.' }
foreach ($required in @('index.html','main.dart.js','main.dart.wasm','flutter_bootstrap.js','speshtv-assets.json','assets/assets/themes/spesha-style.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $required) -PathType Leaf)) { throw "Missing build asset: $required" }
}
$html = Get-Content -LiteralPath (Join-Path $source 'index.html') -Raw
if (-not $html.Contains('<title>SpeshTV</title>')) { throw 'Not a SpeshTV build.' }
if ([regex]::Matches($html, '<base href="[^"]*">').Count -ne 1) { throw 'Expected one HTML base element.' }
$html = [regex]::Replace($html, '<base href="[^"]*">', '<base href="./">')
foreach ($unused in @($stage, $backup, $failed)) {
    if (Test-Path -LiteralPath $unused) { throw "Target already exists: $unused" }
}
New-Item -ItemType Directory -Path $root -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $stage -Recurse
foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse) {
    $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $stage $relative)).Hash) {
        throw "Staging checksum mismatch: $relative"
    }
}
Set-Content -LiteralPath (Join-Path $stage 'index.html') -Value $html -Encoding utf8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../LICENSE') -Destination (Join-Path $stage 'LICENSE-Moonfin.txt')
$assets = Get-Content -LiteralPath (Join-Path $stage 'speshtv-assets.json') -Raw | ConvertFrom-Json
$manifest = [ordered]@{
    name = 'SpeshTV for Moonfin'; upstreamVersion = '2.5.1'; upstreamCommit = 'f18c45b1fbf9b63871b4f93237179f9706154763'
    version = $assets.version; publicPath = '/web/speshtv-0.1.0/moonfin/'
    installedAt = (Get-Date).ToUniversalTime().ToString('o'); backup = $null
    javascriptSha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'main.dart.js')).Hash
    wasmSha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'main.dart.wasm')).Hash
}
$hadLive = Test-Path -LiteralPath $live -PathType Container
if ($hadLive) { $manifest.backup = $backup }
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage 'speshtv-build.json') -Encoding utf8
if ($hadLive) { Rename-Item -LiteralPath $live -NewName ([IO.Path]::GetFileName($backup)) }
try {
    Rename-Item -LiteralPath $stage -NewName 'moonfin'
    $url = $ServerUrl.TrimEnd('/') + $manifest.publicPath
    $served = Invoke-WebRequest -Uri "$url`?speshtv=$stamp" -TimeoutSec 30
    if (-not $served.Content.Contains('<title>SpeshTV</title>') -or -not $served.Content.Contains('<base href="./">')) {
        throw 'Server is not serving the independent frontend.'
    }
    $receipt = Invoke-RestMethod -Uri ($url + 'speshtv-build.json') -TimeoutSec 30
    if ($receipt.javascriptSha256 -ne $manifest.javascriptSha256) { throw 'Served manifest mismatch.' }
} catch {
    if (Test-Path -LiteralPath $live) { Rename-Item -LiteralPath $live -NewName ([IO.Path]::GetFileName($failed)) }
    if ($hadLive) { Rename-Item -LiteralPath $backup -NewName 'moonfin' }
    throw
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../verification/install-receipt.json') -Encoding utf8
Write-Output "Installed independent SpeshTV frontend without restarting Jellyfin: $url"
