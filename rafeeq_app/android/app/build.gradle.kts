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

    // Dart and Kotlin share one authoritative notification ID table.
    // Fail the build if a native ID is missing; never invent a fallback.
    val notificationIdsFile = file("../../lib/core/config/notification_ids.dart")
    val notificationIds = Regex("static const int (\\w+) = (\\d+);")
        .findAll(notificationIdsFile.readText())
        .associate { it.groupValues[1] to it.groupValues[2] }
    buildFeatures { buildConfig = true }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        for (key in listOf("adhan", "assistant", "downloadForeground", "downloadItems", "downloadItemsCount", "prayerStatus")) {
            val field = key.replace(Regex("([a-z])([A-Z])"), "$1_$2").uppercase()
            buildConfigField("int", "NOTIFICATION_$field", notificationIds.getValue(key))
        }
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tito.rafeeq_aldarb"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        testInstrumentationRunner = "com.tito.rafeeq_aldarb.DownloadNotificationRegression"
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
            // Two plugins ship libonnxruntime.so: `onnxruntime` (ORT 1.15.1,
            // ARM only) and `sherpa_onnx` (ORT 1.28.2, «رفيق»'s recogniser).
            // sherpa's C API needs ITS runtime; the reading voice asks the
            // runtime for API 14, which 1.28.2 still serves. Which copy the
            // APK carries is checked after every build (see TRAPS).
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

// «رفيق»: sherpa_onnx 1.13.8 needs ITS ONNX Runtime (1.28.2, C API 28); the
// `onnxruntime` pub package ships 1.15.1 for ARM, and `pickFirsts` above
// took that one for arm64-v8a and armeabi-v7a in the first 3.69.0 build
// (14,203,216 B in the APK against sherpa's 22,249,560) - the recogniser
// would have failed on every phone («The requested API version [28] is not
// available»). Copied into the app's OWN jniLibs, sherpa's copy is the one
// packaged; the reading voice asks the runtime for API 14, which 1.28.2
// still serves (seen reading aloud on emulator-5554). Checked after every
// build by build_github_release.bat.
val sherpaOrtDir = layout.buildDirectory.dir("generated/sherpaOrt/jniLibs")
val copySherpaOrt = tasks.register<Copy>("copySherpaOrt") {
    for (name in listOf(
        "sherpa_onnx_android_arm64",
        "sherpa_onnx_android_armeabi",
        "sherpa_onnx_android_x86_64",
    )) {
        rootProject.findProject(":$name")?.let { plugin ->
            from(plugin.projectDir.resolve("src/main/jniLibs")) {
                include("**/libonnxruntime.so")
            }
        }
    }
    into(sherpaOrtDir)
}
android.sourceSets.getByName("main").jniLibs.srcDir(sherpaOrtDir)
tasks.configureEach {
    if (name.startsWith("merge") && name.endsWith("JniLibFolders")) dependsOn(copySherpaOrt)
}

// sherpa_onnx_web's JavaScript/WASM (~15 MB) comes in with the package's
// assets and is only ever loaded by a web build; `ignoreAssetsPattern` does not
// reach Flutter's assets (tried: all 9 files were still in the APK), so they
// are deleted from the copied assets before packaging.
tasks.configureEach {
    if (name.startsWith("copyFlutterAssets")) {
        doLast {
            outputs.files.forEach { out ->
                out.walkTopDown()
                    .filter { it.isDirectory && it.name == "sherpa_onnx_web" }
                    .toList()
                    .forEach { it.deleteRecursively() }
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Keep the instrumentation classpath on cached, current runtime libraries.
    // Flutter's integration_test runner otherwise pulls core-ktx 1.2.0.
    androidTestImplementation("androidx.core:core-ktx:1.17.0")
    androidTestImplementation("com.google.code.findbugs:jsr305:3.0.2")

    // Only so `RafeeqApplication` can implement `Configuration.Provider` and
    // stop WorkManager initialising itself at every process start — see that
    // class for the measurement behind it. WorkManager itself arrives
    // transitively with `background_downloader`; this version is pinned to
    // the one that plugin declares (9.5.9 -> work-runtime-ktx:2.11.0) so the
    // two can never resolve to different majors behind our back.
    implementation("androidx.work:work-runtime-ktx:2.11.0")

    // (The Microsoft ORT 1.15.1 AAR that supplied x86_64 is gone: sherpa_onnx
    // 1.13.8 ships libonnxruntime.so 1.28.2 for every ABI, and ORT keeps old
    // API versions working - the reading voice asks for API 14 - so ONE
    // runtime, the newer, serves both. See `packaging` above.)
}
