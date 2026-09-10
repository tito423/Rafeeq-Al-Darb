plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tito.rafeeq_aldarb"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tito.rafeeq_aldarb"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Gradle deliberately still signs with the debug key here, and the
            // APK is then RE-SIGNED by `scripts/sign_release.py` with the real
            // release key before it is published.
            //
            // Why not a signingConfig: moving to a new key normally forces an
            // uninstall, because Android refuses an update signed by a
            // different key — and this app carries hundreds of MB of
            // downloaded mushaf pages that an uninstall would destroy. The way
            // out is an APK Signature Scheme v3 SigningCertificateLineage, a
            // signed proof that the new key inherited from the old one, and
            // Gradle's DSL has no field for a lineage. So the signing happens
            // after the build, where apksigner can attach it.
            //
            // Anything built straight out of Gradle is therefore still
            // debug-signed. **Never publish `flutter build apk` output
            // directly** — run `py -3 scripts/sign_release.py` first; it
            // refuses to finish unless the result really carries the release
            // certificate.
            signingConfig = signingConfigs.getByName("debug")
            // P3-46: R8 shrinking was already active on this build (see
            // proguard-rules.pro's own doc comment for how that was
            // confirmed) even with isMinifyEnabled unset — making it
            // explicit here, with our Gson keep rules wired in, is what
            // actually fixes the real flutter_local_notifications crash
            // rather than leaving shrinking's exact on/off state implicit.
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
