# SpeshTV Windows frame telemetry

Vendored from RadicalMuffinMan/media-kit at
50013aee7429633ae2df656982167ca6d21237ce, media_kit_video subdirectory.
Upstream MIT license and copyright retained in LICENSE and source headers.

Windows adds an atomic fresh-render counter, exposed by a read-only method
channel. It counts successfully rendered NEXT_FRAME_INFO/PRESENT frames,
excluding REDRAW and REPEAT, on the existing render thread. Queries read only
the atomic value under the output-map lifetime lock. No screenshot capture,
pixel comparison, extra rendering, or playback timestamps are used.

The app uses this for Windows Live TV frozen-frame recovery. The normal
gpu/gpu-next native-window presenter uses mpv's fresh render-pass telemetry.
Unavailable telemetry disables frame-based detection rather than guessing.
Other platform implementation files retain their upstream behavior.

Build 30000200 adds the FrameProgress read-only method (schema 2): host
visibility/minimization plus fresh, rendered, redraw, repeat and frame-info
failure counters. The legacy FreshFrameCount method remains available.
