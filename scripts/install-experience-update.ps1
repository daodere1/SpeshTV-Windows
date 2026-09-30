$ErrorActionPreference = 'Stop'
$statusPath = Join-Path $PSScriptRoot '../verification/experience-deployment.json'
try {
    & (Join-Path $PSScriptRoot 'install-speshtv-independent.ps1')
    $manifest = Invoke-RestMethod 'http://127.0.0.1:8097/web/speshtv-0.1.0/moonfin/speshtv-assets.json'
    if (!$manifest.version -or !$manifest.bootstrap) { throw 'Branded Moonfin build is not available.' }
    & (Join-Path $PSScriptRoot '../../web-ui-current/install.ps1')
    $source = Join-Path $PSScriptRoot '../../web-ui-current/dist/speshtv.js'
    $installed = 'C:/Program Files/Jellyfin/Server/jellyfin-web/speshtv-0.1.0/speshtv.js'
    $recovered = 'C:/ProgramData/Jellyfin/Server/data/user-iptv-proxy/speshtv-recovery/bundle/speshtv.js'
    $hash = (Get-FileHash -LiteralPath $source).Hash
    if ((Get-FileHash -LiteralPath $installed).Hash -ne $hash) { throw 'Navigation asset verification failed.' }
    if ((Test-Path -LiteralPath $recovered) -and (Get-FileHash -LiteralPath $recovered).Hash -ne $hash) { throw 'Recovery bundle verification failed.' }
    @{success=$true; version=$manifest.version; navigationHash=$hash; serverRestarted=$false; completedAt=(Get-Date).ToUniversalTime().ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding utf8
} catch {
    @{success=$false; error=$_.Exception.Message; completedAt=(Get-Date).ToUniversalTime().ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding utf8
    exit 1
}
