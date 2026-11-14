# Windows live video-frame recovery — 2.8.0+30000199

Build 30000200 supersedes this implementation. See WINDOWS_LIVE_STABILITY_V2.md
for the short-pause, focus, first-frame, telemetry and profile corrections.

The uploaded October 31 report for channel 10292 recovered once, then kept
reporting playing/progress while the picture froze. Playing/buffering flags
and the audio position do not establish video progress.

Windows Live TV now samples actual render activity every two seconds. The
texture presenter counts successfully rendered new frames using mpv's
NEXT_FRAME_INFO flags, excluding redraws/repeats. The counter is atomic and
queried through a read-only method channel with a nonblocking output-map lock.
The native GPU-window presenter uses fresh render-pass samples. Missing
telemetry is unknown and does not trigger a guessed freeze.

Fifteen seconds without fresh video while the stream remains playing and
non-buffering triggers existing bounded live recovery with a fresh resolution,
not a seek. A frozen renderer reports not-playing to recovery bookkeeping;
the 20-second retry-budget proof also checks optional actual-frame health.
Repeated notifications are latched until fresh activity or a session reset.

Pause, disabled video, audio-only media, buffering, seek, background visibility,
stop, source replacement and disposal invalidate/reset observation. Polling is
serial; an in-flight read cannot report against a later session. No screenshots,
pixel comparison, content hashes, credentials or source URLs are added to logs.
This detects stopped rendering; a provider encoding a static picture into
otherwise advancing video frames is not automatically treated as a freeze.

The local media_kit_video fork is documented in
packages/media_kit_video/SPESHTV_FORK.md; its upstream MIT license is retained.

Verification:
- Playback regression batch: 115 passed, including frame freezes with unchanged
  playing/buffering flags, budget proof, pause, missing telemetry, old reads,
  stop/dispose, typed errors bypassing earlier generic-error suppression,
  and existing live/paused/subtitle cleanup paths.
- Real installed libmpv GPU-window probe: fresh render samples advance in
  playback and stop when paused.
- Real installed libmpv texture API probe on static black video: 38 fresh
  frames, zero during pause, 23 after resume. No server requests were made.
- Static analysis: passed with no errors; existing warnings/information remain.
- Native Windows Release builds and Inno Setup installers passed for both
  announcement variants. Final candidates are
  build/windows/distribution/2.8.0+30000199-frame-watch-final-no-announce-unsigned-candidate/
  and the corresponding frame-watch-final-announce-unsigned-candidate directory.
- All 192 inventoried payload files per candidate match their hashes; the
  renderer DLL in each contains VideoOutputManager.FreshFrameCount.
  Evidence: .native/windows-frame-watch-artifact-verification.json.
- Installers are unsigned local test candidates. Channel 10292 has not been
  replayed with the new client; real-service runtime validation remains pending.

No Jellyfin/plugin changes, restart, installer publication or installation.
