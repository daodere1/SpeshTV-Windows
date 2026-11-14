# Windows Distribution Checklist

The current Windows build is a test candidate, not a public release. Do not
promise that signing or a clean antivirus result guarantees no future alerts.

## Packaging

Run `prepare-speshtv-windows-release.ps1` after building. It creates a clean
portable payload without build-time LIB/EXP files, license notices, a file
inventory, and SHA-256 checksums under `build/windows/distribution`.
No server credentials, local app settings, or signing keys are packaged.
Run `build-speshtv-windows-installer.ps1` to compile an explicitly unsigned
test installer from the latest candidate. It verifies every staged file against
the manifest first and updates checksums after compilation. Supply `-IsccPath`
if Inno Setup 6 is not at `.toolchains/inno-setup-6/ISCC.exe`.
The installer definition is `windows/speshtv-installer.iss`. Compile using
Inno Setup 6. It installs per-user without administrator rights, includes
uninstall support, and never deletes user data on uninstall.

## Signing

### Microsoft Store (MSIX)

Store submission is separate from the direct-download EXE signing path below.
Microsoft re-signs accepted MSIX packages after certification; a purchased
public certificate is not required solely for Store distribution. This does
not sign the separately distributed Inno Setup EXE installers.

Before producing a submission package:

- Complete Partner Center developer account verification and reserve the app name.
- Copy the exact Package/Identity/Name, Package/Identity/Publisher and publisher
  display name from Partner Center's Product identity page. These are public
  identifiers, not credentials. Never invent them from the app's branding.
- Replace the placeholder MSIX identity in packaging configuration only after
  those assigned values are known. Do not change direct-install identity casually.
- Use a Store-compatible four-part package version with revision zero, and
  increment it for each submission. The Flutter build counter is not itself
  an MSIX version.
- Review packaged-app protocol registration, writable paths, native playback,
  WebView2 availability, and update behavior. Store installs must not silently
  switch themselves to the direct-download installer.
- Complete the licensing/source and SpeshTV privacy-policy reviews below.
- Prepare listing artwork, screenshots, support/privacy URLs, age ratings,
  disclosures, and reviewer instructions. Do not include production account
  credentials or provider access in the package.
- Build and inspect the MSIX manifest, validate with the Windows App
  Certification Kit, and test install/upgrade/playback on a clean machine.
- Upload to Partner Center for review; do not claim signing, certification or
  publication merely because local packaging succeeds.

Official Store guidance:
https://learn.microsoft.com/windows/apps/publish/get-started
https://learn.microsoft.com/windows/apps/publish/partner-center/open-a-developer-account
https://learn.microsoft.com/windows/apps/publish/publish-your-app/package-version-numbering

### Direct Downloads

Obtain a publicly trusted code-signing identity, preferably Microsoft's
Artifact Signing service, or a trusted CA's supported signing solution.
The Android upload key and a self-signed Windows certificate are not suitable
for public Windows distribution. Do not store private keys in this repository.
Sign the executable before packaging; use SHA-256 and a trusted RFC3161
timestamp. Sign the installer after compilation. Verify with SignTool:

```powershell
signtool verify /pa /all /v SpeshTV.exe
signtool verify /pa /all /v SpeshTV-Windows-x64-Setup.exe
```

Refresh artifact checksums after signing. The staging manifest remains
`publicReady: false` until signing, scanning, licensing, privacy and testing
have been independently reviewed. No automatic publication is configured.

## Security And Functionality

- Scan the final signed artifacts with an up-to-date Microsoft Defender.
- Review scan results; do not infer a clean result from starting a scan.
- Do not upload artifacts to public multi-engine scanners without approval.
- Test a clean Windows 10/11 PC for missing runtimes and WebView2 requirements.
- Test login, local movies, Live TV, VOD, audio/subtitle changes and stop.
- Confirm the Language Failover restart-loop fix on The Omen before release.
- Test install, upgrade, uninstall and preservation of user settings.
- Record release notes and provide downloads through a controlled HTTPS origin.

## Licensing And Privacy

Preserve the fork's GPL license and Moonfin attribution. Inventory all shipped
native libraries, including libmpv/FFmpeg, Flutter, ANGLE, PDFium and WebView2;
Flutter package notices alone do not establish native-library compliance.
Provide complete corresponding source and required build materials for shipped
GPL components, including the exact modified fork and pinned dependency source.
Review LGPL and other native-library obligations before shipping. Do not claim
this checklist or the generated notices are a completed legal review.

The published SpeshTV policy at https://privacy.oriemplx.cc/ explicitly covers
Windows and was reviewed for coverage on October 24, 2026. Use that URL in the
Store listing. Recheck accuracy against each release; this is not a completed
legal review. Do not substitute an inherited Moonfin policy or claim
third-party traffic never occurs.

Official signing guidance:
https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation
