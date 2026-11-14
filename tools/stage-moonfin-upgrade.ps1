param([string]$Base = '2.6.0', [string]$Target = '2.7.0')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$gitArgs = @('-c', "safe.directory=$($root.Replace('\','/'))")
$stage = Join-Path $root ".native/upstream-$Target"
New-Item -ItemType Directory -Force $stage | Out-Null
foreach ($ref in @($Base, $Target)) {
    $dir = Join-Path $stage $ref
    New-Item -ItemType Directory -Force $dir | Out-Null
    $archive = Join-Path $stage "$ref.tar"
    & git @gitArgs archive $ref --output=$archive
    if ($LASTEXITCODE -ne 0) { throw 'Archive failed' }
    & tar -xf $archive -C $dir
    if ($LASTEXITCODE -ne 0) { throw 'Extraction failed' }
}
$merged = Join-Path $stage 'merged'
$results = foreach ($path in (& git @gitArgs diff --name-only $Base $Target)) {
    $old = Join-Path (Join-Path $stage $Base) $path
    $upstream = Join-Path (Join-Path $stage $Target) $path
    $local = Join-Path $root $path
    $output = Join-Path $merged $path
    New-Item -ItemType Directory -Force (Split-Path $output -Parent) | Out-Null
    $status = 'clean'
    if (!(Test-Path $upstream)) {
        $status = if ((Test-Path $local) -and ((Get-FileHash $local).Hash -ne (Get-FileHash $old).Hash)) { 'delete-conflict' } else { 'delete' }
    } elseif (!(Test-Path $local)) {
        if (Test-Path $old) { $status = 'local-delete-conflict' }
        else { Copy-Item $upstream $output }
    } elseif (!(Test-Path $old)) {
        if ((Get-FileHash $local).Hash -eq (Get-FileHash $upstream).Hash) { Copy-Item $local $output }
        else { $status = 'add-conflict' }
    } elseif ((Get-FileHash $local).Hash -eq (Get-FileHash $old).Hash) {
        Copy-Item $upstream $output
    } else {
        Copy-Item $local $output
        if ([IO.Path]::GetExtension($path) -in @('.dart','.arb','.yaml','.json','.kt','.kts','.xml','.md','.txt','.swift','.cpp','.h','.ps1','.sh','.properties','.pro')) {
            foreach ($textPath in @($output,$old,$upstream)) {
                $text = [IO.File]::ReadAllText($textPath).Replace("`r`n", "`n")
                [IO.File]::WriteAllText($textPath, $text, [Text.UTF8Encoding]::new($false))
            }
        }
        & git merge-file $output $old $upstream
        if ($LASTEXITCODE -ne 0) { $status = 'merge-conflict' }
    }
    [pscustomobject]@{path=$path; status=$status}
}
$results | ConvertTo-Json | Set-Content (Join-Path $stage 'manifest.json')
$results | Group-Object status | Select-Object Name,Count | Format-Table
$results | Where-Object status -Like '*conflict*' | Select-Object path,status | Format-Table -AutoSize
