# SpeshTV Android and Android TV Fork

## Windows guide actions (2.8.0+30000201)

The shared guide preserves modal focus and channel identity across controls,
sorting and filters. Numeric channel input, held-select channel actions,
current-user favorites and desktop right-click/Shift+F10 are supported.
Existing Windows player recovery and native frame telemetry are retained.
See WINDOWS_GUIDE_QOL.md for validation and remaining device checks.

## Windows live stability (2.8.0+30000200)

Windows adds bounded repeated-short-rebuffer recovery and a reversible live
cache runway, removes the desktop-inappropriate H264 reference-frame cap,
retains monitoring on visible unfocused windows and records precise build and
renderer-health diagnostics. Native texture telemetry schema 2 reports host
visibility and fresh/rendered/redraw/repeat counts. See WINDOWS_LIVE_STABILITY_V2.md.

## Windows video-frame recovery (2.8.0+30000199)

Windows Live TV observes actual new-rendered-frame activity independently of
audio time and playing/buffering flags. The vendored MIT media_kit_video fork
adds a read-only Windows texture counter; the native GPU presenter uses fresh
render samples. Recovery retains pause/background/session and retry-budget
guards. See WINDOWS_FRAME_RECOVERY.md and packages/media_kit_video/SPESHTV_FORK.md.

## Moonfin 2.8 Windows Integration

Windows/common source now integrates official Moonfin-Core 2.8.0
(d9f4bf241d6dfddf54338f21dcdfde05e75fafc8), using official 2.7.0
as the three-way base. Windows version is 2.8.0+30000196.
SpeshTV branding, themes, Store identity, local-first search/progress,
refresh/cache optimizations, custom guide and playback/session fixes remain.
The customized guide is adapted rather than replaced by upstream's rebuilt
guide. Platform-specific Android/iOS builds were not upgraded here.
See MOONFIN_2_8_INTEGRATION.md for scope and verification.

## Moonfin 2.7 Integration

The working source integrates official Moonfin-Core tag 2.7.0 (36ed696),
using tag 2.6.0 as the three-way merge base. Pre-integration affected files
are preserved under .toolchains/moonfin-27-integration/local.
Client version is 2.7.0+30000185; Android TV build number is 2000060.
SpeshTV branding, application IDs, signing setup, per-user credentials,
custom guide/filter navigation, local-first progress/search deduplication,
HDR handling and optional Windows announcements remain fork features.
The custom guide/player and incremental search are adapted rather than
replaced wholesale. See MOONFIN_2_7_INTEGRATION.md for verification status.

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

## Android TV Alpha

Branch feature/speshtv-android-tv targets version 2.6.0, TV build 2000021.
Run ./build-speshmedia.ps1 -AndroidTv for a debug APK, or add -TestOnly
for remote-navigation verification followed by the mobile regression tests.
The phone build and its version code remain unchanged. Both flavors retain
dev.speshmedia.moonfin; use the TV APK on a separate TV device rather than
replacing the newer-versioned phone installation.

The TV flavor uses a SpeshTV Leanback launcher banner. Guide navigation now
preserves the selected time across vertical moves, starts on a half-hour
boundary, and explicitly handles channel-column arrows and programme entry.
The isolated vertical-navigation check and 139 selected regressions pass,
including explicit STV launcher-icon and adaptive-icon checks.
The complete TV suite has 43 passes and nine failures: deferred row focus,
controls-row focus/traversal, paged-window refresh anchoring, player-return
and back-button focus restoration, and filtered-channel hero updates.
These tests remain enabled and the TV verification command reports failure.
This is an alpha, not a completed TV release. No connected Android TV device
or configured TV emulator was available for playback or visual validation.

For physical-device performance testing, use
./build-speshmedia.ps1 -AndroidTv -Release. This enables Flutter AOT compilation
and Android release shrinking; it does not imply release readiness. With no
release keystore configured, Gradle uses the existing debug signing identity
so this optimized test build can update the debug TV installation in place.
The initial Shield Cylinder recording shows slow startup and an exit during
sign-in, but does not establish the cause. Capture device logcat before
claiming that optimized compilation fixes the crash.

TV build 2000021 replaces native TV country/package/tag dropdowns with
bounded picker dialogs using lazy lists, remote selection and cancellation,
and focus restoration. Fixed landscape controls use a traversal policy that
does not scroll ancestors; phone and web selector behavior is unchanged.
Six filter tests cover existing responsive layouts plus the TV picker and
fixed-header focus regression. The reported Shield disappearing-guide issue
still requires confirmation on hardware after updating the APK.

The Shield retest of 2000021 still shows duplicated controls and black guide
regions. Build 2000022 tests Flutter TextureView composition only on NVIDIA
SHIELD models; other devices retain the default rendering mode. This is a
hardware compatibility experiment, not a confirmed resolution. Validate guide
scrolling, search, playback, and return from playback on the physical Shield.

Build 2000022 did not resolve the Shield corruption. Device logcat reports
repeated invalid TransformLayer matrices during guide navigation. Build
2000023 removes the TextureView experiment and replaces the root TV FittedBox
with explicit finite scaling, bounded overflow, and clipping. Empty viewport
transitions are skipped. Resize and native-video coordinate tests pass;
physical-device resolution remains unconfirmed until the next retest.

Build 2000023 also failed the physical retest; invalid matrices still appear.
Build 2000024 is diagnostic, not a fix. Build with -TvTransformTrace to sample
the guide's release layer tree (at most 120 frames, twice per second) and log
nonfinite/float-overflow matrices and offsets. No account or media data is
included. Normal builds omit the trace. The two diagnostic checks and 139
selected regressions pass. Capture SpeshTransform output during the next
guide navigation reproduction before choosing another workaround.

The 2000024 hardware trace confirmed NaN matrices and offsets in the app layer
tree. The noncompact EpgHeroPreview artwork row stretched vertically inside
an unbounded guide Column. A new test reproduced "BoxConstraints forces an
infinite height" before the fix. Build 2000025 bounds that row to the existing
144 logical-pixel preview height; the regression and 143 selected checks pass.
Bounded tracing remains enabled in the test APK for physical confirmation.

The user confirmed 2000025 resolves the visual collapse. Build 2000026 adds
explicit TV header focus bands: top controls/genres, search and channel jump,
then country/package filters, then the guide. Up restores the last control
section and its remembered child. Back dismisses a visible keyboard before
returning home; picker routes retain their own cancellation. The real-text-field
focus test, Back dispatch check, and 145 selected regressions pass. This APK
uses the normal build without temporary transform tracing.

Build 2000027 gives TV search/channel-number fields explicit horizontal focus
targets when the window keyboard is closed, preserving caret movement when it
is open. Picker dialogs focus the selected row after route entry rather than
letting Cancel take initial focus. Tests cover window insets, both arrow
directions, All and saved selections; 147 selected checks pass.

Build 2000028 includes the live player's previous/next/last-channel controls
in TV remote focus navigation. Up reaches the channel controls, Down returns
to playback controls, and Left/Right traverses available controls. TV channel
buttons use the same focus highlight and Select handling as playback buttons.
Existing selected regressions pass; Shield remote behavior needs device testing.

Build 2000029 publishes the channel list before programme loading completes,
reduces programme requests from 50 to 12 channels, and retries transient guide
failures once without discarding the lineup. Refreshes retain overlapping
programmes until successful replacement; outdated-window responses are ignored.
Selected regressions include a bounded timeout recovery check. Device timing
and upstream server responsiveness still require real-world observation.

Build 2000030 recognizes NCAAB/NCAAF and college sports package labels from
channel names and group tags. Filtered lineup results are reused until model
changes, and channel-ID lookups use an index (kept current on favorite changes).
Tests cover NCAA labels and filter-cache invalidation. Device performance
improvement has not been benchmarked.

Build 2000031 adds bounded in-memory lineup caching scoped to client and user,
background refresh of stale cached lineups, and explicit Refresh bypass.
Overlapping guide requests share pending channel work. Detail episode/season
loads precede optional discovery requests (two at a time); cast lists are
memoized by item identity. Existing bounded artwork caching remains in place.
No playback URLs or watch progress are cached. Tests cover expiry, forced
refresh, isolation by cache key, bounded capacity and overlapping guide loads.

Build 2000033 loads cold lineups in 200-channel pages and exposes the first
page while the rest arrives, preserving filters until completion. Library
paging starts one viewport ahead and near the last 12 focused items; stale
page responses are discarded after browse changes. Low-priority artwork has
one active slot, reserving capacity for visible artwork. Bounded diagnostic
samples report startup/detail/page/guide elapsed times and decoded-image
cache usage without identifiers or credentials. Memory samples are image-cache
usage, not total process RAM. New tests cover progressive pages and reserved
artwork capacity; real-device speed gains require observation.

Build 2000034 routes preview Down through search/filter focus bands, returns
channel-row Left to the preview card, and routes first-row Up through controls.
Selecting a channel in the SpeshTV embedded guide keeps preview mode open;
fullscreen is explicit preview activation. Selections carry the guide's updated
lineup so channels arriving after progressive load can play. Existing selected
regressions pass; preview stability and remote behavior need device testing.

Build 2000035 makes preview Select/Enter activation press-once, consuming held
repeat events. Fullscreen restores focus to Play/Pause rather than Channels,
and the player consumes repeated activation keys. Preview's InkWell no longer
adds a second focus target. A regression test verifies held Select activates
only once. The reported fullscreen bounce requires confirmation on the Shield.
