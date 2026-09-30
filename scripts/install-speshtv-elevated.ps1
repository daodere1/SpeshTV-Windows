$ErrorActionPreference = 'Stop'
$statusPath = Join-Path $PSScriptRoot '../verification/deployment-status.json'
try {
    & (Join-Path $PSScriptRoot 'install-speshtv-independent.ps1')
    @{success=$true; completedAt=(Get-Date).ToUniversalTime().ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding utf8
} catch {
    @{success=$false; error=$_.Exception.Message; completedAt=(Get-Date).ToUniversalTime().ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding utf8
    exit 1
}
