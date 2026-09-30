# SpeshMedia Android Fork

Based on the existing Moonfin-Core checkout at upstream commit
f18c45b1fbf9b63871b4f93237179f9706154763, including the local SpeshTV changes.
Upstream: https://github.com/Moonfin-Client/Moonfin-Core

The original LICENSE and copyright notices are preserved. This fork follows
the upstream GPLv2 license. Distributions must include corresponding source
and the required license notices; do not publish an APK without its source.

The app uses Flutter UI and Moonfin's Android native playback integrations.
The earlier Kotlin/Compose prototype remains separately in ../android.
The working server/web checkout is not edited by Android fork development.

Development application ID: dev.speshmedia.moonfin. This does not replace
the upstream Moonfin app or the Compose prototype. No production signing
or store publishing is configured. Firebase Google Services build integration
is disabled until a separately owned project is configured; push notifications
are not claimed to work in this build.

Build with SPESHMEDIA_CLIENT=true to enable the existing SpeshTV adaptations.
Platform-specific playback and browser-only integrations need device QA.

## Verification Status

57 selected tests pass: progress resolution, channel facets, episode filters,
search transport, repository, view model, channel ranking, progress snapshot
storage, Home snapshot hydration and server-update refresh coordination.
Targeted analysis of the search model, repository, view model and screen is clean.

## Android Search

The inherited unified search supports All, Local, VOD and Live TV sources,
debounced input, generation-based stale-response rejection, partial results,
local-first duplicate resolution and native details/channel navigation.
Channel search now ranks exact numbers first, matches current programme names,
and sorts equal matches by channel number. Cards expose Local/VOD source labels
and channel numbers. Programme matches depend on the server supplying guide data.
These changes do not alter server settings or watch history. APK build number
30000150 identifies this search update. End-to-end Android QA remains required.

Build 30000151 enables the previously web-only local-first Home progress feed,
snapshot hydration, member-list invalidation and socket refresh on Android.
Cached rows render while fresh server progress is fetched. Cold loads still
require metadata checks, and lookup failures do not hide unconfirmed VOD items.
Search identity also removes known language/year suffixes; search library lists
are cached for two minutes per signed-in user, with local libraries queued first.

A mobile debug APK was successfully built on 2026-09-30:
build/app/outputs/flutter-apk/app-mobile-debug.apk.
Run ./build-speshmedia.ps1 to build, or add -TestOnly for the selected tests.
The script temporarily maps the workspace to an unused S: drive to avoid
Windows native build path issues and removes that mapping when finished.
Java selection, native-assets tool invocation and Ninja staging-path length
issues have also been addressed. This is a development build, not a store release.
Do not treat test success as proof of Android device playback or HDR support.
