# Local AGP 9 compatibility patch

Based on flutter_inappwebview_android 1.1.3 from pub.dev. The original LICENSE
is retained. Only android/build.gradle is changed: both build types use
proguard-android-optimize.txt instead of the unsupported proguard-android.txt.
Remove this path override when an upstream compatible release is adopted.
