# AGP 9 adoption

This project uses AGP 9.0.1 and Gradle 9.1.0 with the existing JDK 17
toolchain. Android SDK targets and signing identities are unchanged.

The initial adoption intentionally keeps `android.newDsl=false` and
`android.builtInKotlin=false` while Flutter plugins still use legacy APIs.
This is not a completed migration to the new DSL or built-in Kotlin. Remove
those opt-outs only after auditing and migrating every affected plugin.
Release unit-test tasks remain enabled explicitly; AGP 9 otherwise creates
only the tested build type's unit tests by default.

The local `flutter_inappwebview_android` 1.1.3 override replaces the obsolete
ProGuard defaults rejected by AGP 9. Its patch and upstream license are kept
inside the package. The local `file_picker` 11.0.2 override respects the
built-in Kotlin opt-out instead of checking only the AGP version. No shared
pub cache files are patched.

Release candidates use mobile build 30000161 and TV build 2000042. Earlier
AGP 8.13 signed candidates remain in `.native/release-candidates` as fallbacks.
Run `verify-release-bundle.ps1` and `measure-dex-bundles.ps1` after rebuilding.
Real-device release startup, playback, Cast, notifications, and navigation
must still be smoke-tested before store submission.

## Verified candidates

Both signed bundles passed signature, packaged font, embedded mapping, and
protected entrypoint verification. The release PlaybackBufferBudgetTest
suite passed all four tests with no failures or skipped tests.

Both variants contain 8,251,332 uncompressed DEX bytes with R8 9.0.32:
optimization 83.29%, obfuscation 84.12%, shrinking 83.96%. The previous
optimized AGP 8.13 bundles contained 8,349,008 bytes. These measurements do
not guarantee a Play Console rating or real-device performance improvement.

Windows lint-cache locks during migration were resolved by stopping the
identified idle workspace Gradle daemons. Release lint was not disabled.

References:
- https://developer.android.com/build/releases/agp-9-0-0-release-notes
- https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers
