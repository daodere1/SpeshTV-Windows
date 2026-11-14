# Release DEX optimization

The release configuration uses R8 full mode, optimized resource shrinking,
and class repackaging. Broad Flutter, notifications, Gson, and Cast package
keep rules were replaced by narrower entrypoint rules and library consumer
rules. JNI, Flutter registration, Cast options, and AV1 native entrypoints
remain protected.

Measured R8 metadata before and after:

| Metric | Before | Optimized |
| --- | --- | --- |
| Uncompressed DEX bytes | 9,406,608 | 8,349,008 |
| Optimization | 69.95% | 83.30% |
| Obfuscation | 70.55% | 84.17% |
| Shrinking | 70.35% | 84.01% |

These are bundle metadata measurements, not a guarantee of a particular
Play Console rating or runtime speed. Dart and native libraries are not DEX.

Run `measure-dex-bundles.ps1` after release builds to measure current bundles.
Run `verify-release-bundle.ps1 -Bundle <path>` to check the signature, icon
fonts, embedded mapping, and protected entrypoint names. Preserve release
mapping files for crash diagnosis.

Before publishing, smoke-test signed release playback, channel switching,
Cast, notifications, and app startup on real mobile and TV devices. Static
bundle verification cannot establish reflection or native runtime safety.
