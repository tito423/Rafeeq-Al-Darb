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

    /**
     * Routing a tap on a GROUPED download notification, which the downloader
     * plugin cannot do for us.
     *
     * `background_downloader` offers `taskNotificationTapCallback`, and this
     * app registered one for each of its three download groups. It never
     * fired. MEASURED on emulator-5554: a real 90 MB ruqyah download was
     * started, the app left on Home, the shade pulled down and «تحميل ملفات
     * الرقية الصوتية» tapped — the app came forward on Home. Switching
     * MainActivity to `singleTask`, which the plugin's docs ask for, changed
     * nothing.
     *
     * The reason is in the plugin's own Android source (9.5.9). Every task
     * notification gets a tap intent carrying the task as JSON, but the
     * GROUP notification is built with `addTapIntent(taskWorker, "", …)` — an
     * empty task string — and `BDPlugin.handleIntent` then does
     * `if (taskJsonMapString.isNotEmpty())` before doing anything at all. A
     * grouped notification therefore cannot carry a task, and the Dart
     * callback cannot fire. This app groups all three of its download kinds
     * on purpose (`groupNotificationId`), so a whole-surah download does not
     * put three hundred rows in the shade — which means none of them could
     * ever route.
     *
     * So the intent is read here instead. The plugin still puts its
     * notification config on the intent, and that config carries the
     * `groupNotificationId` this app chose, which is all the destination
     * needs. Held until Dart asks for it, because a cold start has no
     * listener yet.
     */
    private var pendingDownloadTap: String? = null
    private var downloadTapChannel: MethodChannel? = null

    private fun captureDownloadTap(intent: Intent?) {
        if (intent == null) return
        // The app's own download notifications (DownloadForegroundService)
        // name their destination outright.
        val own = intent.getStringExtra(DownloadForegroundService.EXTRA_ROUTE)
        if (own != null) {
            deliverDownloadTap(own)
            return
        }
        if (intent.action != "com.bbflight.background_downloader.tap") return
        val config = intent.getStringExtra(
            "com.bbflight.background_downloader.notificationConfig"
        ) ?: return
        // The group ids are set in `download_engine.dart`; matching on the
        // substring keeps this from having to parse the plugin's JSON shape.
        val what = when {
            // `groupNotificationId`s from `download_engine.dart`. Ruqyah is
            // tested before files because neither string contains the other,
            // but the order documents the intent: most specific first.
            config.contains("rafeeq_quran_audio_group") -> "recitations"
            config.contains("rafeeq_ruqyah_group") -> "ruqyah"
            config.contains("rafeeq_files_group") -> "files"
            else -> return
        }
        deliverDownloadTap(what)
    }

    /** Straight to Dart if it is listening, otherwise held for the pull. */
    private fun deliverDownloadTap(what: String) {
        val channel = downloadTapChannel
        if (channel != null) {
            channel.invokeMethod("tap", what)
        } else {
            pendingDownloadTap = what
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureDownloadTap(intent)
    }

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

        // See `pendingDownloadTap` for why this exists rather than the
        // plugin's own tap callback.
        val tapChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.DOWNLOAD_TAP)
        downloadTapChannel = tapChannel
        tapChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Asked once on startup: was the app launched by tapping a
                // download notification, and which queue was it?
                "takePending" -> {
                    val pending = pendingDownloadTap
                    pendingDownloadTap = null
                    result.success(pending)
                }
                else -> result.notImplemented()
            }
        }
        captureDownloadTap(intent)

        // The rebuilt Adhan module: alarm scheduling + the native adhan
        // player (used by both the real firing and the settings preview).
        // Registered here as well as in AdhanActivity because the two run in
        // separate Flutter engines over the same native singletons.
        AdhanNotifications.ensureChannels(this)
        AdhanChannels.register(this, flutterEngine, this)

        registerNativeStringsChannel(flutterEngine)

        registerDownloadServiceChannel(flutterEngine)

        registerMediaAudioChannel(flutterEngine)

        registerPrayerCardChannel(flutterEngine)

        registerAdhanControlChannel(flutterEngine)
    }
}
