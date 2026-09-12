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
                    PrayerCard.show(
                        this,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                        (call.argument<Number>("when") ?: 0).toLong(),
                        call.argument<String>("nextTitle"),
                        call.argument<String>("nextBody"),
                        (call.argument<Number>("nextWhen") ?: 0).toLong(),
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
