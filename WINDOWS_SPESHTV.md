# SpeshTV Windows Test Build

This native Flutter desktop build shares the SpeshTV fork's screens and uses
the Windows media-kit player. It is not a browser wrapper.

## Run

Extract the entire portable ZIP into one folder and run `SpeshTV.exe`.
Keep the DLLs and `data` directory beside the executable. Sign in with your
normal Jellyfin account. This test build is unsigned.

## Window Position Recovery

Build 2.8.0+30000197 adds a native Windows safeguard alongside Flutter's
saved-geometry check. Normal windows are fitted to the nearest monitor's
current work area when shown, activated, restored programmatically, or when
the display/taskbar layout changes. The title bar remains reachable; oversized
windows shrink to fit. Positions use physical Win32 coordinates to avoid
depending solely on cached Flutter display geometry.

Interactive dragging is allowed until released. Maximized, minimized and
borderless playback windows retain their own placement behavior. The safeguard
runs before plugin dispatch because window_manager consumes placement events.
The native regression harness tests off-screen startup/restoration, title-bar
recovery, dragging, borderless exclusion and display-change recovery.

## Build

Run `build-speshtv-windows.ps1` from this directory. Requirements include
Windows Developer Mode, Visual Studio C++ build tools, the local Flutter SDK,
NuGet at `.toolchains/nuget.exe`, and vcpkg at `.toolchains/vcpkg`.
The script reserves `V:` temporarily and produces
`build/windows/SpeshTV-Windows-x64.zip`.

The pinned media-kit Windows dependency needs `POST_BUILD` in its CMake tar
fallback for the `ANGLE_EXTRACT` target with current CMake. That correction
is applied in this workspace's dependency checkout; retain it when refreshing
the dependency cache. Android code is unaffected.

## Test Before Distribution

Check login, Live TV, channel changes, VOD, subtitles, stopping playback,
and fullscreen on an actual Windows PC. HDR depends on the display, Windows
HDR settings, and playback negotiation; the build alone does not verify HDR.
Upstream Moonfin update prompts are disabled for this Windows fork.

Upstream license and attribution files remain applicable.
