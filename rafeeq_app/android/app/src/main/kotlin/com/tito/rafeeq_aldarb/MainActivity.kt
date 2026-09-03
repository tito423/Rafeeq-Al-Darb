package com.tito.rafeeq_aldarb

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.File

class MainActivity: AudioServiceActivity() {
    private val ADHAN_CHANNEL = "com.tito.rafeeq_aldarb/adhan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Turns a custom-adhan file path (app-private storage, from
                // AdhanCatalogService) into a content:// URI so it can be
                // used as a native notification-alarm sound — the
                // notification sound API cannot read a raw filesystem path
                // from another app's private storage, only a content:// URI
                // it has read permission to.
                "contentUriForFile" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("no_path", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))
                        // Best-effort: let the system's own notification/sound
                        // renderer read it even when this app is not running.
                        // Some OEM skins ignore this; the bundled adhans (played
                        // via a raw resource, not a URI) are unaffected either way.
                        try {
                            grantUriPermission("com.android.systemui", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        } catch (_: Exception) {}
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("uri_failed", e.message, null)
                    }
                }
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
                else -> result.notImplemented()
            }
        }
    }
}
