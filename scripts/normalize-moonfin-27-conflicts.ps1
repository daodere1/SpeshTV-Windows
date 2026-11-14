$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root '.toolchains/moonfin-27-integration'
$remaining = @()
$utf8 = [Text.UTF8Encoding]::new($false)
foreach ($path in (Get-Content "$stage/conflicts.json" -Raw | ConvertFrom-Json)) {
    $local = Join-Path $root $path
    $upstream = Join-Path "$stage/2.7.0" $path
    $base = Join-Path "$stage/2.6.0" $path
    if (!(Test-Path $upstream)) { $remaining += $path; continue }
    if ($path -match '\.arb$') {
        $ours = Get-Content $local -Raw | ConvertFrom-Json -AsHashtable
        $old = Get-Content $base -Raw | ConvertFrom-Json -AsHashtable
        $new = Get-Content $upstream -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $new.Keys) {
            if (!$ours.ContainsKey($key) -or ($old.ContainsKey($key) -and ($ours[$key] | ConvertTo-Json -Depth 30 -Compress) -eq ($old[$key] | ConvertTo-Json -Depth 30 -Compress))) { $ours[$key] = $new[$key] }
        }
        [IO.File]::WriteAllText($local, ($ours | ConvertTo-Json -Depth 30) + "`n", $utf8)
        continue
    }
    foreach ($side in @('local','2.6.0','2.7.0')) {
        $source = Join-Path "$stage/$side" $path
        $target = Join-Path "$stage/normalized/$side" $path
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        [IO.File]::WriteAllText($target, [IO.File]::ReadAllText($source).Replace("`r`n","`n"), $utf8)
    }
    $merged = Join-Path "$stage/normalized/merged" $path
    New-Item -ItemType Directory -Path (Split-Path $merged) -Force | Out-Null
    Copy-Item "$stage/normalized/local/$path" $merged
    & git merge-file $merged "$stage/normalized/2.6.0/$path" "$stage/normalized/2.7.0/$path"
    if ($LASTEXITCODE -eq 0) { Copy-Item $merged $local } else { $remaining += $path }
}
$remaining | ConvertTo-Json | Set-Content "$stage/remaining.json"
$remaining
