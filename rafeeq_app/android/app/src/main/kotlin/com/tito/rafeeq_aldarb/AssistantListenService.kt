package com.tito.rafeeq_aldarb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.ryanheise.audioservice.AudioService

/**
 * «رفيق» listening while the app is in the background.
 *
 * Owner, 2026-09-27: it must hear «يا رفيق» in the background while he has
 * it switched on. Android lets an app keep its microphone open behind other
 * apps only from a foreground service of type `microphone`, started while
 * the app is on screen, with a notification that says so. The listening
 * itself stays in Dart (`RafeeqEar`); this service only keeps the process
 * and its microphone access alive, and offers «إيقاف» in the notification.
 *
 * Its texts come from Dart in the app's language (extras), like the
 * download service's.
 */
class AssistantListenService : Service() {
    companion object {
        const val CHANNEL_ID = "rafeeq_assistant"
        const val NOTIFICATION_ID = BuildConfig.NOTIFICATION_ASSISTANT
        const val ACTION_STOP = "com.tito.rafeeq_aldarb.ASSISTANT_STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_STOP = "stop"
        const val EXTRA_CHANNEL = "channel"

        /** Set when the reader pressed «إيقاف»; Dart reads and clears it. */
        @Volatile var stoppedByUser = false

        /** For «تشخيص رفيق»: whether Android accepted the service, and why not. */
        @Volatile var running = false
        @Volatile var refusedBecause: String? = null

        fun start(context: Context, title: String, text: String, stop: String, channel: String) {
            val i = Intent(context, AssistantListenService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_STOP, stop)
                .putExtra(EXTRA_CHANNEL, channel)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AssistantListenService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * The Dart side of «رفيق» runs in audio_service's cached FlutterEngine,
     * and audio_service DESTROYS that engine when its own AudioService is
     * destroyed - which happens as soon as the activity closes (Back out of
     * the app, or swiped from recents) and nothing is playing. Seen on
     * emulator-5554, 2026-09-30: after Back, `rec stop` at once, the service
     * notification still up, a command heard by nobody (owner's Honor: «لما
     * التطبيق بقفله وانده مش بيظهر ولا بيتفاعل»). A binding from here keeps
     * AudioService - and with it the engine - alive while listening is on.
     */
    private var engineHold: ServiceConnection? = null

    private fun holdEngine() {
        if (engineHold != null) return
        val c = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {}
            override fun onServiceDisconnected(name: ComponentName?) {}
        }
        val ok = try {
            bindService(
                Intent(this, AudioService::class.java).setAction("android.media.browse.MediaBrowserService"),
                c, Context.BIND_AUTO_CREATE,
            )
        } catch (e: Exception) {
            false
        }
        if (ok) engineHold = c
    }

    private fun releaseEngine() {
        engineHold?.let { try { unbindService(it) } catch (_: Exception) {} }
        engineHold = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stoppedByUser = true
            running = false
            releaseEngine()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Rafeeq"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val stop = intent?.getStringExtra(EXTRA_STOP) ?: "Stop"
        val channelName = intent?.getStringExtra(EXTRA_CHANNEL) ?: title
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_LOW)
            ch.setShowBadge(false)
            ch.setSound(null, null)
            nm.createNotificationChannel(ch)
        }
        val flagsPi = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
            flagsPi,
        )
        val stopPi = PendingIntent.getService(
            this, 1,
            Intent(this, AssistantListenService::class.java).setAction(ACTION_STOP),
            flagsPi,
        )
        val n: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(open)
            .addAction(0, stop, stopPi)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
            running = true
            refusedBecause = null
            holdEngine()
        } catch (e: Exception) {
            // Android 14 refuses a microphone service started from the
            // background; the app then listens only while it is open.
            running = false
            refusedBecause = e.javaClass.simpleName + ": " + (e.message ?: "")
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        releaseEngine()
        super.onDestroy()
    }
}
