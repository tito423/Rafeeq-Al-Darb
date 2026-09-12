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
 * The strings Android renders itself - the notification channels, the adhan
 * alert, the download service - pushed from Dart in the language chosen
 * INSIDE the app rather than the device language.
 *
 * Split out of MainActivity.configureFlutterEngine, which registered six
 * channels in one 304-line function. An extension function, so `this` is
 * still the activity and the handler moved verbatim.
 */
fun MainActivity.registerNativeStringsChannel(flutterEngine: FlutterEngine) {
    // The strings Android renders itself — notification channels, the
    // adhan alert, the download service — in the language chosen INSIDE
    // the app. Dart pushes them here on startup and on every language
    // change; see NativeStrings for why Android's own resource qualifiers
    // cannot do this job. The channels are refreshed straight away so a
    // language change shows up in the notification shade without waiting
    // for the next adhan.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.NATIVE_STRINGS)
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
}
