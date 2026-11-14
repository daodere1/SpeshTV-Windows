param()
$ErrorActionPreference = 'Stop'
$directory = Join-Path $env:LOCALAPPDATA 'SpeshMedia/Signing'
$keystore = Join-Path $directory 'speshcast-upload.p12'
$config = Join-Path $directory 'speshcast-upload.json'
if ((Test-Path $keystore) -or (Test-Path $config)) {
    throw 'Signing material already exists. It will not be overwritten.'
}
$jdk = (Get-ChildItem (Join-Path $PSScriptRoot '../android/.toolchains') -Directory -Filter 'jdk-17*' | Select-Object -First 1).FullName
if (!$jdk) { throw 'Configured JDK was not found.' }
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $directory /inheritance:r /grant:r "*$($sid):(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict the signing directory permissions.' }
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$password = [Convert]::ToBase64String($bytes)
$secure = ConvertTo-SecureString $password -AsPlainText -Force
$previous = $env:SPESHCAST_KEY_PASSWORD
try {
    $env:SPESHCAST_KEY_PASSWORD = $password
    & (Join-Path $jdk 'bin/keytool.exe') -genkeypair -keystore $keystore -storetype PKCS12 -alias speshcast-upload -keyalg RSA -keysize 3072 -sigalg SHA256withRSA -validity 10000 -dname 'CN=SpeshCast Upload, OU=App Releases, O=SpeshMedia' -storepass:env SPESHCAST_KEY_PASSWORD -keypass:env SPESHCAST_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Upload key generation failed.' }
    @{
        keystore = $keystore
        alias = 'speshcast-upload'
        storeType = 'PKCS12'
        passwordDpapi = ConvertFrom-SecureString $secure
    } | ConvertTo-Json | Set-Content -LiteralPath $config -Encoding UTF8
    & (Join-Path $jdk 'bin/keytool.exe') -exportcert -rfc -keystore $keystore -alias speshcast-upload -storepass:env SPESHCAST_KEY_PASSWORD -file (Join-Path $directory 'speshcast-upload-certificate.pem')
    if ($LASTEXITCODE -ne 0) { throw 'Public certificate export failed.' }
    & (Join-Path $jdk 'bin/keytool.exe') -list -v -keystore $keystore -alias speshcast-upload -storepass:env SPESHCAST_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Upload key verification failed.' }
} finally {
    $env:SPESHCAST_KEY_PASSWORD = $previous
    $password = $null
    $secure.Dispose()
    [Array]::Clear($bytes, 0, $bytes.Length)
}
