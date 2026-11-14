# Windows live stability — 2.8.0+30000200

## Evidence and limits

The October 31 report generated at 17:44 identifies only SpeshTV 2.8.0;
it cannot establish the exact executable/Dart build that ran its session.
The client machine is different from this build host. Build 199 installers
existed before the session, which makes that build plausible, not proven.
There is no retrospective frame-health/focus telemetry in that report.
The final upstream EOF was approximately five seconds before the user's
stop, below the sustained-freeze timeout. The user clarified that the actual
problem was frequent short pauses, not a picture frozen beyond 20 seconds.

The report's RefFramesNotSupported decision sent 1080p50 H264 through a
server HEVC transcode. Windows libmpv now omits the TV-style H264 reference-
frame cap; other codec, level, resolution and bitrate checks remain. This
permits a compatible source to avoid that otherwise unnecessary transcode.
It does not force direct play against other compatibility restrictions.

## Changes

- Visible but unfocused Windows playback remains monitored. Focus-only
  transitions do not reset the stall deadline. Hidden/minimized, user pause,
  disabled video, seeking and teardown remain excluded.
- The native texture probe reports schema 2, host visibility/minimization,
  fresh frames, rendered frames, redraws, repeats and frame-info errors.
  Valid zero-frame telemetry now gets a 30-second first-frame window;
  established rendering still uses the 15-second freeze window. Late reads
  cannot overwrite a replacement session's observation state.
- The report includes package and compiled build identifiers, feature marker
  frame-watch-v2 and the latest watchdog state even if logging was enabled
  late. State changes and 30-second heartbeats describe eligibility, pending
  reads, missing ABI/telemetry and frame age. Diagnostics cannot break recovery.
  Only fixed status names and numeric counters are added; no credentials,
  stream URLs, screenshots or picture hashes are logged.
- Windows live playback targets a three-second cache runway. Existing cache
  values are restored before VOD, and explicit custom mpv configuration wins.
  Stale asynchronous configuration cannot affect the next source.
- A separate short-rebuffer window detects at least three qualified pauses
  totaling six seconds within a minute, after a 20-second tune warm-up.
  It requests a bounded live-edge rejoin, with at most two such rejoins per
  viewing session and at least two minutes between them. Automatic source
  reopens preserve this allowance; an explicit new viewing session resets it.
  A single brief pause does not retune. Recent interruptions do not count
  as proven healthy playback for replenishing the recovery budget.

This is a client update. No server/plugin configuration, credentials, guide
mapping, watch history, service restart, installation or publishing is involved.

## Verification

- 266 targeted tests passed: short-rebuffer thresholds, warm-up, limits and
  session preservation, cache restoration and stale reads, desktop H264 cap,
  focus/minimization, startup/freeze recovery, diagnostics/redaction, existing
  playback, subtitle teardown and device-profile compatibility checks.
- Final static analysis passed with no errors (180 warnings/informational findings).
- Both build 2.8.0+30000200 Windows installers built successfully. All 192
  inventoried payload files per variant passed hash verification; both contain
  the compiled build identity and native telemetry schema 2.
- Installers remain unsigned and were not installed or published. Actual
  channel playback on the user's PC is still to be validated.
