# SpeshTV for Moonfin

Based on official Moonfin-Core 2.5.1, commit f18c45b1fbf9b63871b4f93237179f9706154763.
This is a customized web build, not an official Moonfin release. Upstream GPL-2.0
license and attribution remain in LICENSE and the existing About screen.

## Included

- Native Moonfin navigation and playback with SpeshTV sign-in, navigation,
  loading, browser-tab and PWA branding.
- Bundled Spesha Style theme. Used only when neither user nor server has supplied
  a theme selection; no preferences are reset by this build.
- Native search with All, Local, VOD and Live TV source selection, 280 ms debounce,
  incremental results and at most three simultaneous library requests per query.
- Per-library first-page search prevents one large catalog from monopolizing the
  former single global query. Up to 48 hits per library and 24 per type are shown.
- Conservative title grouping prefers matching local copies over VOD. Conflicting
  provider IDs and remakes remain separate. Search does not modify watch history.
- The combined Continue Watching & Next Up row on the current server also prefers
  local libraries. Episodes are matched through their parent series metadata;
  local progress wins even when VOD is on a different episode. Confirmed local
  catalog copies suppress VOD progress without inventing local progress or changing
  watch history. VOD-only and unconfirmed titles remain. Identity work uses three
  workers and a ten-minute per-view-model/user identity cache; duplicate-only pages are
  backfilled with independent source offsets, up to five batches per request.
- The combined progress request starts before the other Home section workers.
- Spotlight restores its last successful selection from a six-hour browser
  metadata cache scoped to user, server and source settings, then refreshes in
  the background. At most three libraries are queried concurrently. Image URLs
  are regenerated from the current client; credentials and stream URLs are not
  cached. Entries are limited to 30 titles and 256 KiB.
- Channels match by name or exact channel number. VOD libraries are identified by
  a standalone VOD token in the library name.
- Optional people/game/Seerr requests no longer block library result rendering.
- Query-generation and disposal guards discard stale replies; partial failures
  keep successful results visible and provide a retry control.
- Catalog search skips total-count queries and collection collapsing. Jellyfin
  item/person search gets a 30-second connection/header budget without changing
  playback or normal browsing timeouts. Library/person requests retry transient
  network failures once; authorization and parsing errors are not retried.
  People search follows the library requests, and obsolete queries skip retries
  and deferred people lookup.
- Android-only Media3 event subscription is skipped on non-Android platforms.
- The companion `../web-ui-current` bundle connects Jellyfin's SpeshTV menu to
  this home screen and its Live TV tile directly to the guide, in the same tab.
  Native desktop playback retains its existing bridge. A whitelisted, one-time
  guide destination survives web authentication startup.
- Movie/series filter views explicitly disable collection collapsing when the
  collection-grouping setting is off. Collections themselves remain unchanged.
- Both the HTML loader and Flutter startup screen use SpeshTV branding.
- The web guide has a Return to SpeshTV control and its existing back arrow
  returns home. Channel-name/number search covers the full visible lineup;
  exact-number jump clears active filters and loads nearby program data without
  walking every earlier channel batch.
- Watch preview starts the existing Live TV player in its embedded-guide mode.
  The same video surface stays above the scrolling rows; scrolling/searching
  does not tune another stream. Selecting a channel while previewing tunes it
  without dismissing the guide. The preview frame expands to full playback;
  Stop preview returns to the guide, and Return to SpeshTV stops playback first.
  These controls are web-only; native client behavior is unchanged.

## Live Channel Filters

The SpeshTV guide requests channel Tags and Genres with the existing channel
index. Country, Sports package, and Tag / group selectors filter the complete
accessible lineup locally, including channels without EPG listings. Country
labels use explicit channel-name prefixes or regional group tags (PR, DR, CH,
and other recognized regions); sports packages use saved league-package tags.
The existing provider event group 1118 appears under PPV / Live events, with
ESPN+ and FloSports subsets where explicitly labeled. Custom tags remain
available in Tag / group. Counts describe each option across the user's lineup.

Selections combine with channel search and the existing programme/favorite
filters. Search also matches tags. The guide loads programme data only for the
selected/visible rows, not every channel in a package. Number jump clears these
selections. Desktop shows selectors inline; narrow views open a Filters sheet.
Changing filters does not start or switch playback, modify mappings, or require
administrator access. Selections are local to the open guide, not server defaults.

## Boundaries

Provider credentials, access checks, lineup, import filters and metadata repair
continue to run in the existing User IPTV Proxy server plugin. This web build
uses the signed-in user's existing Moonfin/Jellyfin session, never an admin key.
Roku, native iOS and Jellyfin Desktop apps are not replaced or modified.

SpeshTV's custom player recovery and its remaining custom UI controls are not yet
ported. Moonfin's existing implementations remain active. Local-first progress
currently targets the combined online, single-server row; separate progress rows,
offline mode and multi-server aggregation retain their existing behavior.

## Build And Verify

Flutter 3.44.1 / Dart 3.12.1, matching the upstream web workflow:

```powershell
flutter pub get
flutter test test/util/spesh_search_identity_test.dart test/viewmodels/spesh_search_view_model_test.dart test/repositories/spesh_search_repository_test.dart test/playback/spesh_media3_platform_test.dart test/viewmodels/live_tv_guide_view_model_test.dart
flutter build web --wasm --release --dart-define=SPESHTV_WEB=true --base-href /web/speshtv-0.1.0/moonfin/
node scripts/package-speshtv.mjs
node --test scripts/guide-scroll.test.mjs
node scripts/preview-speshtv.mjs
```

Preview binds only 127.0.0.1:8098 and forwards API requests only to the existing
127.0.0.1:8097 server. No credentials or request bodies are logged. Browser QA uses
scripts/check-web.cjs with PLAYWRIGHT_PATH pointing to the installed Playwright package.

scripts/install-speshtv-independent.ps1 verifies copied assets, preserves the old
SpeshTV frontend in a timestamped sibling backup, swaps web assets, then verifies
the served manifest. The destination is jellyfin-web/speshtv-0.1.0/moonfin, not a
Moonbase plugin directory. It installs a relative HTML base for proxy prefixes.
It restores the old folder if verification fails. It does not restart Jellyfin,
change plugin DLLs, reset user settings, or alter libraries.

The packaging step versions the bootstrap, JavaScript and WebAssembly entrypoints
by content hash so existing Moonfin browser caches cannot keep loading old code.
Verification found an upstream Flutter `didChangeViewFocus` / not-yet-laid-out
semantics warning during anonymous startup, also present in the unmodified app.
The page recovers and renders. This is a remaining upstream issue, not a clean
browser-console claim; the focused Dart tests and analysis pass independently.

Signed-in deployment verification on 2026-09-23 confirmed the branded header,
local Reacher search, TNT channel search, VOD-only Reacher results, same-tab guide
navigation through cold startup, and individually displayed movies. Approved
temporary diagnostic logging captured eight-second connection/header timeouts
for two local libraries and Persons in an All search, while VOD requests returned
200. Diagnostic logging was restored off. The search resilience changes above
address that captured failure; focused tests also cover bounded retry, stale
queries, authorization failures, partial results, and unchanged non-search
timeouts.

The deployed search build `a4f689437c956805` was verified in the signed-in browser
at 18:17 EDT on 2026-09-23: All/Reacher completed with 41 displayed results
(8 movies, 1 series, 24 episodes, 1 collection, 7 people), and VOD/Reacher with
33 (8 movies, 1 series, 24 episodes), without the partial-source warning.
The server stayed running, diagnostic logging remained off, and the previous
frontend was retained by the installer. These counts reflect capped display
results, not a claim to enumerate every matching episode in the catalog.

Guide verification on 2026-09-23 covered a jump to channel 4001, TNT filtering,
TNT preview at 1920x1080 with advancing playback time while scrolling, desktop
and 375px mobile preview layout, and returning home with the video paused and
unloaded (readyState 0). Six focused guide/control/navigation tests passed,
including exact jump beyond the initial guide batch and 320/1280px controls.

## Update Isolation And Touch Scrolling

The Moonbase 2.3 update introduced stock Moonfin Web 2.6 and a new plugin folder.
As of 2026-09-23, SpeshTV is hosted independently at
`/web/speshtv-0.1.0/moonfin/`. Jellyfin's Live TV and SpeshTV links use that path;
the browser header launcher also opens it after verifying the build manifest.
Desktop native playback keeps its existing bridge. `/Moonfin/Web/` remains the
upstream stock frontend; replace direct bookmarks with the independent URL.

Use `scripts/install-experience-update.ps1` to install both this build and the
companion navigation/recovery bundle. The old `install-speshtv.ps1` is a legacy
in-plugin installer requiring an explicit plugin path; do not use it for normal
deployments. Moonbase updates no longer own or overwrite the customized files.
This does not merge new upstream 2.6 features into this 2.5.1-based fork. Rebase
and test those separately. A Jellyfin installer that removes all of jellyfin-web
can still remove the independent frontend; rerun the experience installer in
that case. The existing server recovery bundle covers only the navigation assets,
not the complete Flutter build.

The web root disables document overscroll. A capturing, non-passive touchmove
guard prevents the native webview from scrolling alongside Flutter on all app
screens, including Home, libraries, search and the guide. It checks the event's
composed path for a Flutter surface instead of depending on the route. Native
text, select and video controls, ordinary DOM outside Flutter, multi-touch and
uncancelable events are excluded. Node tests cover those boundaries. A real iOS-app retest is
still required for WKWebView bounce behavior; desktop checks do not emulate it.

## Continue Watching And Next Up Cache

The SpeshTV single-server combined Home row restores a user/server/settings-scoped
browser snapshot before requesting fresh Resume and Next Up results. It retains
local-first deduplication and never copies VOD progress into local watch history.
The snapshot lasts at most 30 minutes and stores at most 60 cards / 512 KiB of
display metadata and progress, not source URLs, tokens, or media sources. Every
Home load revalidates; the cache lifetime is not the refresh interval.

The existing session WebSocket invalidates the snapshot on the signed-in user's
UserDataChanged messages, LibraryChanged messages, and reconnects. Updates are
coalesced for two seconds with one request in flight and a queued follow-up.
Library changes and reconnects clear the short-lived identity cache. A one-minute visible
Home fallback covers missed events, and returning from playback refreshes the
row. Hidden Home views invalidate on events but do not poll or schedule requests.

Successful empty responses remove completed cards and clear the snapshot. Failed
or partial refreshes retain an already displayed successful row rather than
turning an error into an empty result. Revision guards discard superseded
responses; ordered storage writes cannot undo a later invalidation. Reappearing
progress restores a previously empty row in its configured Home position.

This cache applies to the combined SpeshTV web Home row, not stock Moonfin,
separate unmerged rows, native clients, or the existing multi-server path.
Server notifications contain item IDs rather than playback positions, so the
client fetches current progress instead of guessing it from the notification.
The metadata snapshot references artwork; image bytes retain normal HTTP/image
caching behavior.

Progress requests now use the original SpeshTV's lean field list, disable total
counting, and use the user-scoped Resume route with an explicit video filter.
Read-only comparison measured the old rich Resume request at 23.8 seconds and
the video-filtered lean request at 0.66 seconds (individual endpoint timings,
not full Home render times). Requests have a 30-second ceiling and the combined
feed has a 35-second outer limit. No-count page totals are normalized so a full
page cannot falsely end pagination. Normal item/search/playback timeout defaults
are unchanged. SpeshTV's Next Up Home row no longer scans the 100 most
recently watched episodes just for ordering; it retains server order for equal
last-played dates. Movie identities reuse provider IDs already in the feed;
duplicate searches target only accessible local libraries, without redundant
candidate ancestry reads. Identity results persist for ten minutes per user/view
model, with library-change and reconnect invalidation; playback positions still
refresh normally. The first cache fill still requires successful server responses
and deduplication. Fallback timers request fresh
data without invalidating a slow fetch; actual server-change events invalidate.
