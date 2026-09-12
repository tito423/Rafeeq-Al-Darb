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
 * Start, update and stop the foreground service that keeps this process from
 * being frozen while a download runs.
 *
 * Split out of MainActivity.configureFlutterEngine, which registered six
 * channels in one 304-line function. An extension function, so `this` is
 * still the activity and the handler moved verbatim.
 */
fun MainActivity.registerDownloadServiceChannel(flutterEngine: FlutterEngine) {
    // P3-46: start/stop the real foreground service that keeps this
    // process from being frozen/killed while backgrounded during an
    // active download — see DownloadForegroundService's own doc for why
    // this exists. `DownloadManager` (Dart) is the sole caller, exactly
    // when its active-download count crosses 0.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.DOWNLOAD_SERVICE).setMethodCallHandler { call, result ->
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
            "updateItem" -> {
                try {
                    DownloadForegroundService.updateItem(
                        this,
                        call.argument<String>("key") ?: "",
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        call.argument<Int>("done") ?: 0,
                        call.argument<Int>("total") ?: 0,
                    )
                } catch (_: Exception) {}
                result.success(null)
            }
            "finishItem" -> {
                try {
                    DownloadForegroundService.finishItem(this, call.argument<String>("key") ?: "")
                } catch (_: Exception) {}
                result.success(null)
            }
            "update" -> {
                try {
                    DownloadForegroundService.update(
                        this,
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        call.argument<Int>("done") ?: 0,
                        call.argument<Int>("total") ?: 0,
                    )
                } catch (_: Exception) {}
                result.success(null)
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
}
