# SpeshCast Upload Signing

Store builds are opt-in and preserve the existing SpeshTV test package and signing.

## Key Storage

The upload key is in `%LOCALAPPDATA%/SpeshMedia/Signing/speshcast-upload.p12`.
Its alias is `speshcast-upload` and its store type is PKCS12.
The public certificate is `speshcast-upload-certificate.pem` in that directory.
Only the public certificate may be shared; never publish the keystore or passwords.

`speshcast-upload.json` contains the keystore path and a Windows DPAPI-encrypted
password. Builds decrypt it only within the current process and restore the prior
signing environment afterward. The signing directory has restricted permissions.
Signing files are outside the repository and OneDrive workspace.

The encrypted password is tied to this Windows account. Copying that JSON to
another computer is not a portable backup. Before production, arrange an offline
backup of the keystore and recoverable password in a secure password manager.
No portable backup has been created automatically.

## Build Commands

From this project directory:

```powershell
.\build-speshmedia.ps1 -Release -AppBundle -StoreRelease
.\build-speshmedia.ps1 -AndroidTv -Release -AppBundle -StoreRelease
```

Store builds refuse debug signing. Mobile uses `com.speshmedia.speshcast`;
TV uses `com.speshmedia.speshcast.tv`. Both launcher names are SpeshCast.
These packages install separately from the SpeshTV test app.

Outputs:

- `build/app/outputs/bundle/mobileRelease/app-mobile-release.aab`
- `build/app/outputs/bundle/androidTvRelease/app-androidTv-release.aab`

These are signed candidate bundles, not a certification of Play Store readiness.
Before submission, complete internal SpeshCast branding, platform/store checks,
license and attribution review, privacy declarations, and internal-track testing.
