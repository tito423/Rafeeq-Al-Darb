pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

// ─── Build directory redirect ─────────────────────────────────────────────
// Flutter expects the APK at <project>/build/app/outputs/flutter-apk/.
// layout.buildDirectory.dir(relative) resolves RELATIVE TO THE DEFAULT BUILD
// DIR (projectDir/build), so:
//   ":"        -> android/build      + ../../build      = rafeeq_app/build
//   ":app"     -> android/app/build  + ../../../build/app = rafeeq_app/build/app
// Plugin subprojects live in the pub cache on C:\ drive and redirecting them
// across drives (to E:\) triggers a Kotlin compiler crash ("different roots"),
// so they are left at their default location.
gradle.beforeProject {
    val target = when (path) {
        ":" -> "../../build"
        ":app" -> "../../../build/app"
        else -> null
    }
    if (target != null) {
        layout.buildDirectory.value(layout.buildDirectory.dir(target).get())
    }
}
