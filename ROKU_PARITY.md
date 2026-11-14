# Android parity with recent Roku updates

Roku 0.2.33-0.2.38 review:

- Series playback now prioritizes positive saved episode positions over aggregate series watch state, and preserves that position during hydration.
- Series queue loading and background Next Up checks have bounded waits. Disposed detail screens ignore late Next Up results.
- Android already publishes details before secondary requests and uses metadata image tags; those paths remain unchanged.
- Full-screen trailer sound remains independent of Spotlight mute preferences. Android retains its native 360p trailer policy and external YouTube fallback.
- Roku's sidebar event handling is platform-specific; Android focus navigation is retained rather than copying SceneGraph handlers.

Shared mobile and Android TV changes:

- Spotlight publishes the first eligible library response before waiting for others.
- Two concurrent library requests share a ten-second catalog budget, including fallback requests.
- Spotlight snapshots now work on native SpeshTV clients as well as web, scoped by server, user, and settings. Cached entries are rechecked against parental and genre filters.
- Continue Watching/Next Up get priority, with a bounded wait; remaining home rows load automatically with two request slots, without requiring scrolling.
- Seerr trailers try up to three distinct trailer/teaser candidates. Only playback failure advances the candidate; pressing Back cancels. Native trailer completion returns to the previous route.

Existing Android implementations retained:

- Episodes inherit series theme music, with generation checks and playback/lifecycle cleanup.
- Downloaded subtitles select in place rather than restarting the item.
- Guide requests target visible channels, share pending work, and preserve the channel list on programme timeout.
- Seerr browsing defaults to All and has named sort/filter options.

Roku's temporary MP4 download workaround is platform-specific and is not copied into Android's native/embed playback paths. Background theme video was deferred in the Roku work and is not part of this parity update.

Regression tests cover progressive batches, trailer candidate selection, subtitle selection, guide loading, home-row failure handling, spotlight snapshots, and progress caches. Actual playback and perceived loading speed still require phone/TV device testing.
