param(
    [Parameter(Mandatory=$true)][string]$PluginRoot,
    [string]$ServerUrl = 'http://127.0.0.1:8097'
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../build/web')).Path
$root = (Resolve-Path -LiteralPath $PluginRoot).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$live = [IO.Path]::GetFullPath((Join-Path $root 'frontend'))
$stage = [IO.Path]::GetFullPath((Join-Path $root "frontend-speshtv-stage-$stamp"))
$backup = [IO.Path]::GetFullPath((Join-Path $root "frontend-speshtv-backup-$stamp"))
$failed = [IO.Path]::GetFullPath((Join-Path $root "frontend-speshtv-failed-$stamp"))
foreach ($target in @($live, $stage, $backup, $failed)) {
    if (-not $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Target outside plugin directory: $target"
    }
}
if (-not (Test-Path -LiteralPath $live -PathType Container)) { throw 'Existing frontend missing; no changes made.' }
if ((Get-Item -LiteralPath $live).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to replace a linked frontend.' }
foreach ($required in @('index.html','main.dart.js','main.dart.wasm','flutter_bootstrap.js','assets/assets/themes/spesha-style.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $required) -PathType Leaf)) { throw "Missing build asset: $required" }
}
if (-not (Get-Content -LiteralPath (Join-Path $source 'index.html') -Raw).Contains('<title>SpeshTV</title>')) { throw 'Not a SpeshTV build.' }
foreach ($unused in @($stage, $backup, $failed)) {
    if (Test-Path -LiteralPath $unused) { throw "Target already exists: $unused" }
}
Copy-Item -LiteralPath $source -Destination $stage -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../LICENSE') -Destination (Join-Path $stage 'LICENSE-Moonfin.txt')
foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse) {
    $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $stage $relative)).Hash) {
        throw "Staging checksum mismatch: $relative"
    }
}
$manifest = [ordered]@{
    name = 'SpeshTV for Moonfin'; upstreamVersion = '2.5.1'; upstreamCommit = 'f18c45b1fbf9b63871b4f93237179f9706154763'
    installedAt = (Get-Date).ToUniversalTime().ToString('o'); backup = [IO.Path]::GetFileName($backup)
    javascriptSha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'main.dart.js')).Hash
    wasmSha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'main.dart.wasm')).Hash
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage 'speshtv-build.json') -Encoding utf8
Rename-Item -LiteralPath $live -NewName ([IO.Path]::GetFileName($backup))
try {
    Rename-Item -LiteralPath $stage -NewName 'frontend'
    $served = Invoke-WebRequest -Uri "$ServerUrl/Moonfin/Web/?speshtv=$stamp" -TimeoutSec 30
    if (-not $served.Content.Contains('<title>SpeshTV</title>')) { throw 'Server is not serving the new frontend.' }
    $receipt = Invoke-RestMethod -Uri "$ServerUrl/Moonfin/Web/speshtv-build.json" -TimeoutSec 30
    if ($receipt.javascriptSha256 -ne $manifest.javascriptSha256) { throw 'Served manifest mismatch.' }
} catch {
    if (Test-Path -LiteralPath $live) { Rename-Item -LiteralPath $live -NewName ([IO.Path]::GetFileName($failed)) }
    Rename-Item -LiteralPath $backup -NewName 'frontend'
    throw
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../verification/install-receipt.json') -Encoding utf8
Write-Output "Installed SpeshTV web assets without restarting Jellyfin. Backup: $backup"
