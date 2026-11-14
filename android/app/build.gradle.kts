import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

fun loadAndroidTvVersionCode(rootDir: File, fallback: Int): Int {
    val pubspec = rootDir.resolve("../pubspec.yaml")
    if (!pubspec.exists()) return fallback

    val line = pubspec.readLines().firstOrNull {
        it.trimStart().startsWith("android_tv_build_number:")
    } ?: return fallback

    val rawValue = line.substringAfter(":", "").trim()
    return rawValue.toIntOrNull() ?: fallback
}

fun loadAndroidTvVersionName(rootDir: File, fallback: String): String {
    val pubspec = rootDir.resolve("../pubspec.yaml")
    if (!pubspec.exists()) return fallback

    val line = pubspec.readLines().firstOrNull {
        it.trimStart().startsWith("android_tv_version:")
    } ?: return fallback

    val rawValue = line.substringAfter(":", "").trim()
    return rawValue.ifEmpty { fallback }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val keystoreStoreType = keystoreProperties
    .getProperty("storeType")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }

val speshCastStoreBuild = System.getenv("SPESHCAST_STORE_BUILD") == "true"
val releaseStoreFile = if (speshCastStoreBuild) {
    System.getenv("SPESHCAST_KEYSTORE")?.let { File(it) }
} else rootProject.file("app/release.keystore")
val releaseKeyAlias = if (speshCastStoreBuild) System.getenv("SPESHCAST_KEY_ALIAS")
    else keystoreProperties.getProperty("keyAlias")
val hasReleaseKeystore = releaseStoreFile?.exists() == true && !releaseKeyAlias.isNullOrBlank()
if (speshCastStoreBuild && !hasReleaseKeystore) {
    throw GradleException("SpeshCast store builds require a release upload keystore; debug signing is not permitted.")
}

android {
    namespace = "org.moonfin.androidtv"
    compileSdk = 36
    ndkVersion = "28.2.13676358"
    val androidTvVersionCode = loadAndroidTvVersionCode(rootDir, flutter.versionCode)
    val androidTvVersionName = loadAndroidTvVersionName(rootDir, flutter.versionName)

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Fallback so the main manifest's ${enableImpeller} always resolves;
        // TV flavors override this to "false".
        manifestPlaceholders["enableImpeller"] = "true"
    }

    flavorDimensions += "device"
    productFlavors {
        val baseAppId = "dev.speshmedia.moonfin"
        val baseAppName = if (speshCastStoreBuild) "SpeshCast" else "SpeshTV"
        val testIdSuffix = System.getenv("MOONFIN_TEST_ID_SUFFIX").orEmpty()
        val mobileAbis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        val tvAbis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        create("mobile") {
            dimension = "device"
            applicationId = if (speshCastStoreBuild) "com.speshmedia.speshcast" else baseAppId
            versionCode = flutter.versionCode
            versionName = flutter.versionName
            ndk { abiFilters += mobileAbis }
            manifestPlaceholders["appName"] = baseAppName
        }
        create("mobile-beta") {
            dimension = "device"
            applicationId = "$baseAppId.beta"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
            ndk { abiFilters += mobileAbis }
            manifestPlaceholders["appName"] = "$baseAppName Beta"
        }
        create("androidTv") {
            dimension = "device"
            applicationId = if (speshCastStoreBuild) "com.speshmedia.speshcast.tv" else baseAppId + testIdSuffix
            versionCode = androidTvVersionCode
            versionName = androidTvVersionName
            ndk { abiFilters += tvAbis }
            manifestPlaceholders["appName"] =
                if (testIdSuffix.isEmpty()) baseAppName else "$baseAppName Test"
            // Impeller off by default on TV: the GLES fallback stutters on
            // TV-box GPUs. MoonfinApplication turns it on for boxes where it
            // runs on Vulkan.
            manifestPlaceholders["enableImpeller"] = "false"
        }
        create("androidTv-beta") {
            dimension = "device"
            applicationId = "$baseAppId.beta"
            versionCode = androidTvVersionCode
            versionName = androidTvVersionName
            ndk { abiFilters += tvAbis }
            manifestPlaceholders["appName"] = "$baseAppName Beta"
            manifestPlaceholders["enableImpeller"] = "false"
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = releaseStoreFile
                storeType = if (speshCastStoreBuild) "PKCS12" else keystoreStoreType
                storePassword = if (speshCastStoreBuild) System.getenv("SPESHCAST_KEY_PASSWORD")
                    else keystoreProperties["storePassword"] as String?
                keyAlias = releaseKeyAlias
                keyPassword = if (speshCastStoreBuild) System.getenv("SPESHCAST_KEY_PASSWORD")
                    else keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts += setOf("**/libc++_shared.so")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    implementation("com.google.android.gms:play-services-cast-framework:22.3.1")
    implementation("eu.simonbinder:sqlite3-native-library:3.52.0")
    implementation("androidx.tvprovider:tvprovider:1.1.0")
    implementation("androidx.work:work-runtime-ktx:2.12.0")
}

val flutterApkOutputDir = layout.buildDirectory.dir("app/outputs/flutter-apk")

tasks.register<Copy>("copyAndroidTvDebugApkForFlutter") {
    from(flutterApkOutputDir.map { it.file("app-androidtv-debug.apk") })
    into(flutterApkOutputDir)
    rename { "app-debug.apk" }
}

tasks.matching { it.name == "assembleDebug" }.configureEach {
    finalizedBy("copyAndroidTvDebugApkForFlutter")
}
