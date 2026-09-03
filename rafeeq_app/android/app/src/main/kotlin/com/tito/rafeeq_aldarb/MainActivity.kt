package com.tito.rafeeq_aldarb

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.File

class MainActivity: AudioServiceActivity() {
    private val ADHAN_CHANNEL = "com.tito.rafeeq_aldarb/adhan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Turns a custom-adhan file path (app-private storage, from
        // AdhanCatalogService) into a content:// URI so it can be used as a
        // native notification-alarm sound — the notification sound API
        // cannot read a raw filesystem path from another app's private
        // storage, only a content:// URI it has read permission to.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "contentUriForFile") {
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
            } else {
                result.notImplemented()
            }
        }
    }
}
