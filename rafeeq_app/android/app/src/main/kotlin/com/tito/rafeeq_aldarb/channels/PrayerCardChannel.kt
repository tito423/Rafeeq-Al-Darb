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
import org.json.JSONArray
import org.json.JSONObject
import com.tito.rafeeq_aldarb.adhan.AdhanNotifications

/**
 * The ongoing next-prayer notification that Android draws itself.
 *
 * Split out of MainActivity.configureFlutterEngine, which registered six
 * channels in one 304-line function. An extension function, so `this` is
 * still the activity and the handler moved verbatim.
 */
fun MainActivity.registerPrayerCardChannel(flutterEngine: FlutterEngine) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.PRAYER_CARD).setMethodCallHandler { call, result ->
        try {
            when (call.method) {
                "show" -> {
                    // The schedule crosses the channel as a list of maps;
                    // JSON is what PrayerCard stores, so it is built here
                    // rather than parsed twice.
                    val events = JSONArray()
                    @Suppress("UNCHECKED_CAST")
                    (call.argument<List<Map<String, Any?>>>("events") ?: emptyList()).forEach { e ->
                        events.put(
                            JSONObject()
                                .put("label", e["label"] as? String ?: "")
                                .put("body", e["body"] as? String ?: "")
                                .put("when", (e["when"] as? Number)?.toLong() ?: 0L)
                        )
                    }
                    PrayerCard.show(
                        this,
                        events.toString(),
                        (call.argument<Number>("elapsedMs") ?: 0).toLong(),
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                    )
                    result.success(null)
                }
                "hide" -> {
                    PrayerCard.hide(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("prayer_card", e.message, null)
        }
    }
}
