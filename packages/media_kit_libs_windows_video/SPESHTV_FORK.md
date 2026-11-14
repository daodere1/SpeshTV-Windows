# Windows media-kit native library

Vendored from RadicalMuffinMan/media-kit commit
50013aee7429633ae2df656982167ca6d21237ce,
libs/windows/media_kit_libs_windows_video. MIT license and upstream notices
are retained. Vendoring prevents a partial shared Git package cache from
omitting Windows playback libraries. The CMake tar extraction fallback has an
explicit POST_BUILD timing, required by CMP0175 on a clean build. Decoder and
playback behavior are unchanged.
