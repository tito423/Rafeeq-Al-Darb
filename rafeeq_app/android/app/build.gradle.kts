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
            // ONLY the two ABIs a phone actually has.
            //
            // `--target-platform android-arm,android-arm64` on the Flutter
            // side drops the ENGINE for x86_64 but not the four plugin `.so`
            // files (onnxruntime 15.77 MiB, sqlite3, dartjni, datastore),
            // which every plugin ships for every ABI. That left a `lib/x86_64/`
            // folder in the APK with no `libflutter.so` or `libapp.so` in it,
            // and Android picks its primary ABI from the folders it SEES: on
            // an x86_64 device the app installed and then died on launch with
            // «dlopen failed: libflutter.so is for EM_AARCH64 (183) instead of
            // EM_X86_64 (62)». Caught on emulator-5554 while checking the
            // signed 3.45.0 APK, which is the only reason it did not ship.
            //
            // Debug builds keep every ABI, because emulator-5554 is x86_64 and
            // it is where this project verifies everything (CLAUDE.md §1.3).
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

    // The book reader's open voice runs on ONNX Runtime through the
    // `onnxruntime` pub package, which bundles libonnxruntime.so for ARM
    // only. On an x86_64 device (Chromebooks, the emulator) the voice failed
    // with «libonnxruntime.so not found». Microsoft's own AAR of the SAME
    // version (1.15.1, see dependencies) supplies x86_64; the ARM copies are
    // the package's, the Java binding's JNI shim is never used, and 32-bit
    // x86 is not an ABI Flutter builds for.
    packaging {
        jniLibs {
            pickFirsts += "**/libonnxruntime.so"
            excludes += listOf("**/libonnxruntime4j_jni.so", "lib/x86/**")
        }
    }
}

// A PARTIAL ABI SET MAKES A BROKEN APK - recorded so nobody tries it again.
//
// `--target-platform android-arm,android-arm64` drops the Flutter ENGINE for
// x86_64 but NOT the four plugin `.so` files every plugin ships for every ABI
// (onnxruntime 15.77 MiB, sqlite3, dartjni, datastore). The APK then has a
// `lib/x86_64/` folder with no `libflutter.so` and no `libapp.so`, Android
// picks its primary ABI from the folders it SEES, and on an x86_64 device the
// app installs and dies on launch with «dlopen failed: libflutter.so is for
// EM_AARCH64 (183) instead of EM_X86_64 (62)». Caught on emulator-5554 while
// checking the signed 3.45.0 APK - which is the only reason it did not ship.
//
// Removing the folder as well needs BOTH a release-scoped
// `jniLibs.excludes += "lib/x86_64/**"` AND a narrowed `pickFirsts`, because a
// pickFirst beats an exclude and the one above matches every ABI.
// `ndk.abiFilters` on the build type does nothing here; that was tried with
// the native-lib intermediates deleted.
//
// None of it ships. The owner's rule is compatibility: «يشتغل مع اي نوع من
// انواع الاندرويد فوق سبعة ويشتغل على اي نوع من معمارية». minSdk is 24
// (Android 7.0) and all three ABIs Flutter supports are in the APK.

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Only so `RafeeqApplication` can implement `Configuration.Provider` and
    // stop WorkManager initialising itself at every process start — see that
    // class for the measurement behind it. WorkManager itself arrives
    // transitively with `background_downloader`; this version is pinned to
    // the one that plugin declares (9.5.9 -> work-runtime-ktx:2.11.0) so the
    // two can never resolve to different majors behind our back.
    implementation("androidx.work:work-runtime-ktx:2.11.0")

    // Only for its x86_64 libonnxruntime.so — see `packaging` above. Must stay
    // at the ORT version the `onnxruntime` pub package was built against.
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.15.1")
}
