package com.tito.rafeeq_aldarb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * P3-46: real-device feedback — starting a download, then switching away to
 * another app, left the download (and, on some builds, seemingly the whole
 * app) stuck/hung. `DownloadManager`'s own download loop has no bug in it —
 * every call it makes is already defensive — the real cause is structural:
 * a backgrounded app with no foreground service is just an ordinary cached
 * process to Android, and modern Android (especially power-management-
 * aggressive OEM skins, the same family of behavior already worked around
 * for the Adhan via battery-optimization-exemption/autostart settings) can
 * freeze or kill a cached process's CPU execution outright — not just throttle
 * its network socket — which would stall the *entire* single-isolate Dart VM,
 * not only the download.
 *
 * This service's only job is to exist and be genuinely in the foreground
 * (`startForeground`) for as long as at least one download is actually
 * running — that alone raises the whole hosting process to foreground-service
 * priority, which is what protects it from that freeze/kill. It does not run
 * the download itself (that stays exactly where it was, in Dart/`dio`); it is
 * purely the OS-facing signal "this process is doing real, user-requested,
 * user-visible work right now." Started/stopped from Dart via
 * `DownloadForegroundServiceBridge` exactly when `DownloadManager`'s active-
 * download count goes 0→1 / 1→0, so it is never left running with nothing to
 * protect (a permanent always-on foreground service would be excessive here
 * and against the whole point of it being an honest signal).
 */
class DownloadForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "rafeeq_download_service"
        private const val NOTIFICATION_ID = 4800
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val EXTRA_TITLE = "title"
    }

    private fun ensureChannel() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        // Deliberately NOT short-circuiting on an existing channel: creating it
        // again under the same id updates its name and description (importance
        // and sound are the immutable parts), which is how a language change
        // reaches a channel that was created in the previous language.
        val channel = NotificationChannel(
            CHANNEL_ID,
            NativeStrings.get(this, NativeStrings.DL_CHANNEL),
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = NativeStrings.get(this, NativeStrings.DL_CHANNEL_DESC)
        channel.setShowBadge(false)
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String?): Notification {
        val openApp = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = openApp?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title ?: NativeStrings.get(this, NativeStrings.DL_TITLE))
            .setContentText(NativeStrings.get(this, NativeStrings.DL_BODY))
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                ensureChannel()
                val notification = buildNotification(intent?.getStringExtra(EXTRA_TITLE))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
        }
        // Deliberately NOT START_STICKY: `DownloadManager` (Dart side) is the
        // single source of truth for "is anything actually downloading" and
        // explicitly calls stop when its own active-download count hits
        // zero — this service being restarted by the OS with a stale/no
        // download to protect would just be a permanent phantom notification.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
