# SpeshTV Microsoft Store Submission Draft

Status: local review package only. Not submitted, certified, signed by Microsoft,
or approved for public release.

## Identity And Links

- Display name: SpeshTV
- Publisher display name: SpeshCaster
- Package identity: SpeshCaster.SpeshTV
- Publisher: CN=28D726F4-131C-4CAE-AC94-E02C2A5DFBBB
- Store ID: 9NWFFH7RTP8S
- Website: https://apps.oriemplx.cc/
- Privacy policy: https://privacy.oriemplx.cc/
- Privacy contact: privacy@oriemplx.cc (not yet confirmed as a technical-support contact)

The public privacy policy was read on October 24, 2026. It explicitly covers
Windows, connected servers, local storage, diagnostics, external integrations,
and update checks. This records coverage, not a legal or certification opinion.

## Initial Package

New local review candidate (October 29):
build/windows/store/2.8.0.0-review/SpeshTV-2.8.0.0-x64.msix, built from
2.8.0+30000196 with announcements disabled. MakeAppx validation and archive
identity verification passed. This unsigned replacement has not been
uploaded; the existing 2.7.0.0 Partner Center draft is unchanged.
See MOONFIN_2_8_INTEGRATION.md for integration and test scope.

- Version: 2.7.0.0, x64, Windows desktop only; minimum Windows build 19041.
- Source build: 2.7.0+30000195, no-announcements variant.
- Path: build/windows/store/2.7.0.0-review/SpeshTV-2.7.0.0-x64.msix
- Reproducible staging command:

```powershell
./build-speshtv-store.ps1 -CandidateDirectory 'build/windows/distribution/2.7.0+30000195-activity-sort-no-announce-unsigned-candidate'
```

The script verifies the staged file hashes and creates an isolated payload.
MakeAppx manifest validation passed. Package identity was read back from the
archive. No certificate installation or trust-store changes were performed.
The package is intentionally unsigned for Store review/submission; it is not
an ordinary sideload installer. Existing EXE installers are not signed by this.

## Listing Copy For Review

Short description:

SpeshTV is a media client for your Jellyfin and Emby servers.

Description:

Browse and play media from a server you choose and are authorized to access.
SpeshTV brings movies, series, Continue Watching, Next Up, search, and supported
Live TV libraries together in a Windows desktop experience.

A compatible server and account are required. Media, subscriptions, IPTV
credentials and server access are not included. Features and playback support
depend on your connected server, content, hardware and settings.

SpeshTV is derived from the Moonfin open-source project. It is an independent
fork and is not operated by Moonfin's developers.

## Required Before Submission

- Confirm Partner Center account verification and product identity.
- Confirm a technical-support URL or contact; do not invent one.
- Supply clean screenshots without personal libraries, tokens or account data.
- Prepare Store tile/listing artwork at Partner Center's required dimensions.
- Complete the content/age-rating and privacy questionnaires accurately.
- Explain runFullTrust: the existing Flutter/Win32 client and native playback
  dependencies require the packaged desktop execution model. It does not
  request administrator rights or claim Xbox compatibility.
- Supply reviewer instructions and approved test access if requested. Do not
  package or publish production server/provider credentials.
- Review GPL/LGPL and other native dependency obligations. Include required
  complete corresponding source and build materials for the exact release.
- Run Defender on the final artifact and record results.
  Local attempt on October 24 reported AntivirusEnabled=False; no clean scan
  result was established and no antivirus configuration was changed.
- Validate with Windows App Certification Kit and test an installed MSIX on
  clean Windows hardware, including login, local/VOD/Live TV, HDR, stop/recovery,
  protocol activation, downloads, writable paths, update and uninstall behavior.
- Confirm WebView2/runtime dependency handling on the clean test machine.
- Submit only after the above checks; Microsoft signs after certification.

Local packaging success is not proof of Store certification or license
compliance. Existing direct-install settings may not automatically migrate into
the package's per-user storage and need an explicit upgrade/migration test.

## Official References

- https://learn.microsoft.com/windows/apps/publish/get-started
- https://learn.microsoft.com/windows/apps/publish/publish-your-app/package-version-numbering
- https://learn.microsoft.com/windows/apps/develop/smart-app-control/code-signing-for-smart-app-control
