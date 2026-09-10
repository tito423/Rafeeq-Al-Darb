package com.tito.rafeeq_aldarb

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import com.tito.rafeeq_aldarb.adhan.AdhanChannels
import com.tito.rafeeq_aldarb.adhan.AdhanNotifications

class MainActivity: AudioServiceActivity() {
    private val ADHAN_CHANNEL = "com.tito.rafeeq_aldarb/adhan"
    private val DOWNLOAD_SERVICE_CHANNEL = "com.tito.rafeeq_aldarb/download_service"
    private val NATIVE_STRINGS_CHANNEL = "com.tito.rafeeq_aldarb/native_strings"

    /*
     * NO showWhenLocked / turnScreenOn here — deliberately, and this is a
     * removal, not an omission.
     *
     * P3‑53 set both on this activity, on the reasoning that the Adhan alert
     * arrives as a full-screen intent. It does not arrive here: the alert is
     * `AdhanActivity`, which lives in its own task and declares both flags
     * itself. What these lines actually did was make **every** launch of the
     * app draw over the lock screen and wake the display — tap a quote
     * reminder, a surah reminder, a finished download, and the whole app is
     * open on a locked phone with no unlock. The owner reported it as
     * «التطبيق ساعات بيفتح بعد اللوك اسكرين», and it is a privacy problem as
     * much as a surprise: anyone holding the phone could read and use it.
     *
     * The adhan keeps its lock-screen takeover. Nothing else gets one.
     */

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The rebuilt Adhan module: alarm scheduling + the native adhan
        // player (used by both the real firing and the settings preview).
        // Registered here as well as in AdhanActivity because the two run in
        // separate Flutter engines over the same native singletons.
        AdhanNotifications.ensureChannels(this)
        AdhanChannels.register(this, flutterEngine, this)

        // The strings Android renders itself — notification channels, the
        // adhan alert, the download service — in the language chosen INSIDE
        // the app. Dart pushes them here on startup and on every language
        // change; see NativeStrings for why Android's own resource qualifiers
        // cannot do this job. The channels are refreshed straight away so a
        // language change shows up in the notification shade without waiting
        // for the next adhan.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_STRINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        @Suppress("UNCHECKED_CAST")
                        val values = (call.arguments as? Map<String, String>).orEmpty()
                        NativeStrings.sync(this, values)
                        AdhanNotifications.ensureChannels(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // P3-46: start/stop the real foreground service that keeps this
        // process from being frozen/killed while backgrounded during an
        // active download — see DownloadForegroundService's own doc for why
        // this exists. `DownloadManager` (Dart) is the sole caller, exactly
        // when its active-download count crosses 0.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, DownloadForegroundService::class.java)
                    intent.action = DownloadForegroundService.ACTION_START
                    intent.putExtra(DownloadForegroundService.EXTRA_TITLE, call.argument<String>("title"))
                    try {
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Best-effort: a device refusing the foreground-service
                        // start (rare OEM policy) must not break the download
                        // itself, which keeps running in Dart regardless.
                        result.success(false)
                    }
                }
                "stop" -> {
                    val intent = Intent(this, DownloadForegroundService::class.java)
                    intent.action = DownloadForegroundService.ACTION_STOP
                    try {
                        startService(intent)
                    } catch (_: Exception) {}
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // P3-19: Android 14+ (API 34) added a *separate*, per-app,
                // user-granted toggle for full-screen-intent notifications —
                // the USE_FULL_SCREEN_INTENT manifest permission alone no
                // longer guarantees the Adhan alert can wake the screen over
                // the lock screen; without this, Android silently downgrades
                // it to an ordinary heads-up notification. Below API 34 the
                // manifest permission is still the whole story, so this
                // always reports true there (nothing extra to grant).
                "canUseFullScreenIntent" -> {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val can = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
                    result.success(can)
                }
                // Opens the system settings screen where the user grants the
                // toggle above (API 34+ only — the intent action doesn't
                // exist on older versions).
                "openFullScreenIntentSettings" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                        intent.data = Uri.parse("package:$packageName")
                        try {
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("open_failed", e.message, null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                // P3-44: real-device feedback (Honor X9c, Magic OS) showed
                // the Adhan notification getting killed within seconds of
                // posting — the notification's own flags are already
                // correct (ongoing, autoCancel=false, max importance/
                // priority, no timeoutAfter); this is Android's *process*
                // being killed by the OEM's own aggressive background-app
                // manager, a layer standard battery-optimization exemption
                // doesn't cover. Every major skin with this behavior ships
                // its own "auto-start"/"protected apps" manager Activity —
                // no public API exists to query or grant it, only these
                // well-known per-OEM component names to launch directly.
                // Tries every one that could plausibly match this device's
                // manufacturer, falls back to the generic App Info screen
                // (never a silent no-op) if none of them resolve.
                "openAutostartSettings" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val candidates = mutableListOf<Pair<String, String>>()
                    if (manufacturer.contains("xiaomi")) {
                        candidates.add("com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity")
                    }
                    if (manufacturer.contains("honor")) {
                        candidates.add("com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                        candidates.add("com.hihonor.systemmanager" to "com.hihonor.systemmanager.optimize.process.ProtectActivity")
                    }
                    if (manufacturer.contains("huawei") || manufacturer.contains("honor")) {
                        candidates.add("com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                        candidates.add("com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity")
                    }
                    if (manufacturer.contains("oppo")) {
                        candidates.add("com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                        candidates.add("com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity")
                    }
                    if (manufacturer.contains("vivo")) {
                        candidates.add("com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                    }
                    if (manufacturer.contains("oneplus")) {
                        candidates.add("com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")
                    }

                    var opened = false
                    for ((pkg, cls) in candidates) {
                        try {
                            val intent = Intent()
                            intent.component = android.content.ComponentName(pkg, cls)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            opened = true
                            break
                        } catch (_: Exception) {
                            // this candidate doesn't exist on this build — try the next
                        }
                    }
                    if (!opened) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                        } catch (_: Exception) {}
                    }
                    result.success(opened)
                }
                // Best-effort: is this manufacturer one we actually have a
                // known autostart-manager candidate for? Used only to decide
                // whether to show the settings card at all — `false` doesn't
                // mean the device is safe, just that this app doesn't know a
                // specific screen to send the user to for it.
                "hasKnownAutostartSettings" -> {
                    val m = Build.MANUFACTURER.lowercase()
                    val known = m.contains("xiaomi") || m.contains("honor") ||
                        m.contains("huawei") || m.contains("oppo") ||
                        m.contains("vivo") || m.contains("oneplus")
                    result.success(known)
                }
                else -> result.notImplemented()
            }
        }
    }
}
