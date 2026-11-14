# Windows guide quality of life port

Ports the Roku 0.3.5 guide interaction improvements through the shared Flutter
guide, retaining the existing SpeshTV desktop player and branding.

Windows acceptance checks:

- Search/filter focus survives guide data and preview updates. Escape dismisses
  a dialog without navigating the guide underneath it.
- Channel number entry requests numeric input; desktop search retains native
  caret navigation rather than remote-style arrow interception.
- Left from a channel reaches the preview or upper controls. Returning Down
  restores the selected channel by ID, or clamps its former row when removed.
- Channel actions provide fullscreen, preview and the current user's favorite
  toggle; a failed favorite save restores the prior value.
- Held Select opens actions once and consumes its repeat/release. Right-click
  and keyboard context-menu access provide desktop alternatives.

No Roku-specific HE-AAC restriction is applied to Windows' mpv decoder.
Channel 100 upstream replay remains a separate plugin investigation.

The Windows full-guide regression also caught an idle focus-return issue:
posting a callback did not itself schedule a frame. The return path now requests
a frame explicitly, and a test verifies Left/Down restores channel row 2.

Validation: 25 guide model/grid tests and 51 targeted interaction, favorites,
input and Windows playback tests passed. Logs are `.native/windows-guide-model-tests.log`
and `.native/windows-guide-qol-tests.log`.

A broader run of the older upstream full-guide suite reported 34 failures
(`.native/windows-guide-standard-tests.log`). Examples include a dot versus slash
title separator, absent old window controls and different header geometry.
Those fixtures have not been reconciled with this customized guide; this is not
a claim that the complete upstream test suite passes. Device testing remains
necessary for held remote input and playback transitions.

App and changed-test analysis passed with no errors (173 warning/information
findings). An initial whole-tree analysis also traversed unconfigured vendor
example and standalone package test projects; those are outside the app check.

Both Windows 2.8.0+30000201 variants built successfully, including their Inno
Setup installers. All 192 manifest files in each staged payload passed SHA-256
verification. Executable version and compiled guide/build/recovery markers
were verified; results are in `.native/windows-guide-artifact-verification.json`.

Installers are under `build/windows/distribution/`, in the
`2.8.0+30000201-guide-qol-announce-unsigned-candidate` and
`2.8.0+30000201-guide-qol-no-announce-unsigned-candidate` directories.
They are unsigned test builds and were not installed or published.

The final idle-frame scheduling change
was made after the Android APKs were packaged; those APKs need a future rebuild
to include that small shared follow-up.
