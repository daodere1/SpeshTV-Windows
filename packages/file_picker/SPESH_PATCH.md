# Local AGP 9 compatibility patch

Based on file_picker 11.0.2 from pub.dev, retaining its original LICENSE.
android/build.gradle checks android.builtInKotlin as well as the AGP version
before deciding whether to apply KGP and configure kotlinOptions. This keeps
Kotlin sources compiled when an AGP 9 application opts out of built-in Kotlin.
Remove this override when an upstream compatible release is adopted.
