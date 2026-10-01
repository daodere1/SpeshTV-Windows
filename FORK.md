# SpeshMedia Android Fork

Based on the existing Moonfin-Core checkout at upstream commit
f18c45b1fbf9b63871b4f93237179f9706154763, including the local SpeshTV changes.
Upstream: https://github.com/Moonfin-Client/Moonfin-Core

## Moonfin 2.6 Upgrade

The upgrade/moonfin-2.6.0 branch merges official tag 2.6.0
(b86bbe6021eff5befdf311134bf3e831c032f21f). The speshmedia-android branch
retains the working 2.5.1 checkpoint c9061b6; nothing is pushed upstream.
The upgrade uses an isolated Flutter 3.47.2 SDK in .toolchains and mobile
version 2.6.0, build 30000154. It preserves the SpeshMedia application ID.

The customized Live TV guide/player and search view model are retained rather
than replaced by upstream's redesigned versions. This is a customized 2.6
integration, not a claim that every upstream guide/search behavior is present.
Upstream carousel callers are adapted to the retained guide interface.
The Android launcher icon uses the existing teal SpeshTV television mark,
including adaptive, round and monochrome resources.
Full lib analysis reports no errors (124 warnings/style notices remain).
104 selected regression tests pass on Flutter 3.47.2, including Kids Mode,
custom guide, Android-only native startup, search and progress cache refresh.
Device playback and HDR validation are still required after APK installation.

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

## SpeshTV Branding

Build 30000157 uses SpeshTV as the Android application name, localized UI brand,
default theme label, exit prompt, loading logo and screensaver logo. New public
downloads use Downloads/SpeshTV; stored paths for existing downloads are not
migrated. The package ID, internal theme keys and Moonfin plugin API paths stay
unchanged for compatibility. About credits Moonfin as the upstream project and
retains its source, license and support links. Run tools/rebrand-localizations.ps1
with PowerShell 7 after an upstream merge to apply the same label changes without
renaming ARB keys or URLs.

## Combined Library Browsing

Build 30000156 prefers confirmed local copies over VOD matches in unscoped
combined library, genre and studio browsing. Specific libraries and playlists
retain their editions. Matching uses provider IDs or normalized title/year,
preserves explicit conflicting language suffixes and release years, and does
not merge conflicting IDs through an ID-less intermediary. Unknown sources
remain visible. Only duplicate candidates need cached source lookups, with
bounded concurrency and a two-second timeout per lookup.

Matches are resolved as pages arrive; a local copy on a later page replaces
the earlier VOD card in place. This does not scan unseen pages or copy watch
history. Raw server offsets drive pagination; visible totals settle when the
last page arrives. Duplicate-only pages backfill up to five pages per request.
