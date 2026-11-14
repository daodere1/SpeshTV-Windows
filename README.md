# SpeshTV for Windows

SpeshTV is a customized media client for Jellyfin and Emby, built on Moonfin-Core.
This repository contains the source for the SpeshTV Windows desktop client.
Other platform source is retained because the application and its vendored
packages share Flutter code. Windows source baseline: 2.8.0+30000202.

## Features

- SpeshTV branding and STV app artwork.
- SpeshTV, SpeshFlix, SpeshPrime and SpeshApple themes.
- Local-first search and deduplicated Continue Watching / Next Up.
- Cached home content and Spotlight with background refresh and recovery.
- Live TV preview, full-screen playback, channel switching and recovery.
- Country, sports-package and tag filters; numeric channel entry.
- Guide navigation, held-select actions, right-click and Shift+F10 channel menus.
- Windows native video-frame monitoring and bounded live playback recovery.
- Series seasons, watched counts, episode filters and resume controls.
- Platform-specific playback capabilities and HDR handling.

The client connects to servers you configure. It does not include a media
subscription, provider credentials, channels or a hosted content service.

## Build

Use Flutter 3.47.2 / Dart 3.13 and Visual Studio Build Tools with the Desktop
development with C++ workload and Windows SDK. Native archive support needs
the x64 Windows libarchive dependency from vcpkg.

```sh
flutter pub get
flutter gen-l10n
flutter build windows --release --dart-define=SPESHMEDIA_CLIENT=true --dart-define=DISTRIBUTION_CHANNEL=speshtv-windows --dart-define=SPESHTV_ANNOUNCEMENTS=false
```

`build-speshtv-windows.ps1` creates the portable announcement build; add
`-NoAnnouncements` for the other variant. The local helper expects Flutter at
`.toolchains/flutter-3.47.2` and vcpkg at `.toolchains/vcpkg`. Supply
`-ToolchainRoot` and optionally `-PubCache` to use installed toolchains and a
shared package cache elsewhere, or use the Flutter commands above.
`prepare-speshtv-windows-release.ps1` stages a candidate, and
`build-speshtv-windows-installer.ps1` compiles its Inno Setup installer.

Signing keys, configured API keys, credentials, diagnostics, caches and compiled
installers are excluded. Configure your own signing before public distribution.
See [Windows distribution](WINDOWS_DISTRIBUTION.md) and [guide verification](WINDOWS_GUIDE_QOL.md).
The latest validation passed 76 targeted tests; broader legacy guide fixtures
remain unreconciled as documented. Inherited upstream publishing workflows are
disabled; this repository does not automatically publish releases.

## Project links

- [Source and issues](https://github.com/daodere1/SpeshTV-Windows)
- [Releases](https://github.com/daodere1/SpeshTV-Windows/releases)
- [Customization notes](FORK.md)
- [Privacy](PRIVACY_POLICY.md)

Existing application IDs, platform channels, preference keys and internal
Moonfin package names are retained for installed-app compatibility. They are
implementation identifiers, not the displayed product brand.

## Credits and license

SpeshTV is an independent fork, not an official Moonfin release. Thanks to
[Moonfin-Core](https://github.com/Moonfin-Client/Moonfin-Core), Jellyfin, Emby,
Flutter and the authors of the included dependencies. Upstream attribution and
third-party notices remain in their source files. The license accompanying this
customized source is preserved in [LICENSE](LICENSE); vendored packages retain
their own licenses. Upstream development history is retained in Git.
