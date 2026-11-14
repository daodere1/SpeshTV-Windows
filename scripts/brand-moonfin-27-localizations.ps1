$root = Split-Path $PSScriptRoot -Parent
$utf8 = [Text.UTF8Encoding]::new($false)
foreach ($file in Get-ChildItem "$root/lib/l10n" -Filter '*.arb') {
    $data = Get-Content $file.FullName -Raw | ConvertFrom-Json -AsHashtable
    $changed = $false
    foreach ($key in @($data.Keys)) {
        $value = $data[$key]
        if ($key.StartsWith('@') -or $value -isnot [string] -or $value -match 'https?://') { continue }
        if ($value -match '(?i)moonfin') {
            $data[$key] = $value -replace '(?i)moonfin', 'SpeshTV'
            $changed = $true
        }
    }
    if ($changed) { [IO.File]::WriteAllText($file.FullName, ($data | ConvertTo-Json -Depth 30) + "`n", $utf8) }
}
