package com.tito.rafeeq_aldarb

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tito.rafeeq_aldarb.adhan.AdhanNotifications

/**
 * Battery-optimisation and exact-alarm permissions, and the lock-screen
 * behaviour the adhan alert needs.
 *
 * Split out of MainActivity.configureFlutterEngine, which registered six
 * channels in one 304-line function. An extension function, so `this` is
 * still the activity and the handler moved verbatim.
 */
fun MainActivity.registerAdhanControlChannel(flutterEngine: FlutterEngine) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.ADHAN).setMethodCallHandler { call, result ->
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
