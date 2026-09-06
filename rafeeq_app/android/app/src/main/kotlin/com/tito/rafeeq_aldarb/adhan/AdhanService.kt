package com.tito.rafeeq_aldarb.adhan

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * Owns one firing Adhan: the audio, the alert notification, the wake lock,
 * and putting [AdhanActivity] on screen.
 *
 * It runs as a real foreground service so the OS cannot freeze or kill the
 * process mid-adhan, and it is started from [AdhanAlarmReceiver] — i.e. from
 * an **exact alarm broadcast**, which is on Android's own exemption list for
 * both "start a foreground service from the background" (Android 12+) and
 * "start an activity from the background" (Android 10+). That exemption is
 * what makes the direct startActivity below legal on Android 14/15, and it
 * is why the alarm is armed with setAlarmClock rather than a plain
 * setExactAndAllowWhileIdle.
 *
 * The Stop / Mute notification actions are PendingIntents straight back into
 * this service, so they act on [AdhanPlayer] in the same process that owns
 * it — no Dart isolate has to spin up first, which is why they now work even
 * when the app itself is dead.
 */
class AdhanService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var spec: AdhanSpec? = null
    private var muted = false

    private val autoStop = Runnable {
        Log.i(TAG, "adhan hit the safety timeout - stopping")
        finish()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_FIRE -> {
                val s = AdhanSpec.fromIntent(intent)
                if (s == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                fire(s)
            }
            ACTION_MUTE -> {
                muted = true
                AdhanPlayer.mute()
                spec?.let { updateNotification(it) }
            }
            ACTION_STOP -> finish()
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun fire(s: AdhanSpec) {
        spec = s
        muted = false
        current = s

        // 1) Become a foreground service *first* - Android gives a service
        //    started from the background only a few seconds to do this.
        startAsForeground(s)

        // 2) Hold the CPU for the length of the adhan. The screen is held
        //    separately by AdhanActivity (FLAG_KEEP_SCREEN_ON) so a non
        //    full-screen mode never keeps the display on.
        acquireWakeLock()

        // 3) The sound. Native MediaPlayer on the alarm stream - see
        //    AdhanPlayer's doc for why this is not just_audio.
        val started = AdhanPlayer.start(this, s) {
            // Natural end of the recording: tear everything down exactly as
            // the Stop button would, so the alert never outlives the adhan.
            handler.post { finish() }
        }

        // 4) The screen. Two independent paths on purpose - see AdhanActivity.
        if (s.isFullScreen) {
            try {
                startActivity(AdhanActivity.intentFor(this, s))
            } catch (e: Exception) {
                // Blocked background-activity start on a locked-down skin;
                // the notification's fullScreenIntent is the other path.
                Log.w(TAG, "direct AdhanActivity start refused", e)
            }
        }

        // A sound that never started (a deleted custom file, a missing raw
        // resource) must not leave a silent service running for ten minutes.
        val limit = if (started) MAX_ADHAN_MS else SILENT_FALLBACK_MS
        handler.removeCallbacks(autoStop)
        handler.postDelayed(autoStop, limit)
    }

    private fun startAsForeground(s: AdhanSpec) {
        AdhanNotifications.ensureChannels(this)
        val notification = AdhanNotifications.buildAlert(this, s, muted)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                AdhanNotifications.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(AdhanNotifications.NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(s: AdhanSpec) {
        try {
            NotificationManagerCompat.from(this).notify(
                AdhanNotifications.NOTIFICATION_ID,
                AdhanNotifications.buildAlert(this, s, muted),
            )
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS revoked mid-adhan - the audio and the
            // full-screen alert are unaffected, so this is not fatal.
            Log.w(TAG, "could not refresh the adhan notification", e)
        }
    }

    private fun finish() {
        handler.removeCallbacks(autoStop)
        AdhanPlayer.stop()
        AdhanActivity.finishIfShowing()
        current = null
        releaseWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        NotificationManagerCompat.from(this).cancel(AdhanNotifications.NOTIFICATION_ID)
        stopSelf()
    }

    private fun acquireWakeLock() {
        if (wakeLock != null) return
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "rafeeq:adhan").apply {
            setReferenceCounted(false)
            acquire(MAX_ADHAN_MS)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.takeIf { it.isHeld }?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    override fun onDestroy() {
        handler.removeCallbacks(autoStop)
        releaseWakeLock()
        current = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "AdhanService"

        const val ACTION_FIRE = "com.tito.rafeeq_aldarb.adhan.FIRE"
        const val ACTION_STOP = "com.tito.rafeeq_aldarb.adhan.STOP"
        const val ACTION_MUTE = "com.tito.rafeeq_aldarb.adhan.MUTE"

        /** Hard ceiling - no adhan recording is anywhere near this long. */
        private const val MAX_ADHAN_MS = 10 * 60 * 1000L

        /** The sound could not be opened: do not sit silently for ten minutes. */
        private const val SILENT_FALLBACK_MS = 60 * 1000L

        /** The Adhan currently firing, or null. Read by the method channel. */
        @Volatile
        var current: AdhanSpec? = null
            private set

        fun fire(context: Context, spec: AdhanSpec) {
            val intent = Intent(context, AdhanService::class.java).also {
                it.action = ACTION_FIRE
                spec.writeTo(it)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        /** Best-effort stop - a no-op when nothing is firing. */
        fun stop(context: Context) {
            if (current == null) {
                AdhanPlayer.stop()
                return
            }
            val intent = Intent(context, AdhanService::class.java).also {
                it.action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
                // The service is already gone; make sure the audio is too.
                AdhanPlayer.stop()
            }
        }

        fun mute(context: Context) {
            if (current == null) {
                AdhanPlayer.mute()
                return
            }
            val intent = Intent(context, AdhanService::class.java).also {
                it.action = ACTION_MUTE
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
                AdhanPlayer.mute()
            }
        }
    }
}
