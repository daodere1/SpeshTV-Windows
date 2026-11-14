# ProGuard / R8 keep rules for Moonfin release builds.
#
# Most Flutter plugins ship their own consumer ProGuard rules inside their AARs,
# which R8 applies automatically. The rules below are defensive keeps for code
# reached via reflection, JNI/FFI, or Gson that R8 cannot see and would
# otherwise strip, causing release-only crashes.

# Let Flutter's plugin rules and @Keep annotations protect reflected entrypoints.
# JNI still requires stable names for FlutterJNI.
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-dontwarn io.flutter.embedding.**

# --- flutter_local_notifications (uses Gson reflection for scheduled payloads)
# Notification models and callbacks carry @Keep in plugin v21.
-keepattributes Signature
-keepattributes *Annotation*
# Gson generic type tokens / serialized model fields.
# Gson ships its own consumer rules for TypeToken and adapters.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# --- media_kit / libmpv native bindings -------------------------------------
-keep class com.alexmercerind.** { *; }
-keep class media_kit_video.** { *; }
-dontwarn com.alexmercerind.**

# --- Google Cast framework (referenced via OPTIONS_PROVIDER class name) ------
# Cast ships consumer rules; this app-specific class is also loaded by name.
-keep class org.moonfin.androidtv.MoonfinCastOptionsProvider { public <methods>; }

# --- audio_service ready flag (reset by name in AudioServiceState) -----------
-keepclassmembers class com.ryanheise.audioservice.AudioServicePlugin {
    boolean flutterReady;
}

# --- sqlite3 native library (loaded by name; drift uses FFI) -----------------
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# --- General safety: keep native methods and annotated members ---------------
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepattributes EnclosingMethod,InnerClasses

# Keep protected JNI/reflection class names; repackage everything else.
-repackageclasses ''
