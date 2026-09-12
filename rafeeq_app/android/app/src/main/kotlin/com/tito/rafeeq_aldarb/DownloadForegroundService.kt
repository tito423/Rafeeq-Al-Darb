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
        /** Where a tap should land — read by MainActivity. */
        const val EXTRA_ROUTE = "rafeeq.download.route"

        /** True between a start and a stop, so an update never posts a
         *  notification for a service that is not running — that would be a
         *  permanent phantom, the very thing this class exists to avoid. */
        @Volatile var running = false

        private const val GROUP = "rafeeq_downloads_items"

        /** Downloads with a notification of their own, by key. */
        private val items = java.util.concurrent.ConcurrentHashMap<String, Int>()

        private fun itemId(key: String): Int = 4900 + (key.hashCode() and 0x7fffffff) % 90

        /**
         * One notification per download — «يتم الآن تحميل مصحف كذا وتحتها مصحف
         * وتحتها، ويتجمّعوا في جروب» — instead of one line rewritten by
         * whichever download spoke last. The service's own notification becomes
         * the group's summary, so Android folds the items under it.
         *
         * Not ongoing, and each carries a timeout that every update renews: if
         * the process dies without a stop, an item clears itself instead of
         * staying in the shade for ever, which is the defect the service's
         * notification was introduced to end.
         */
        fun updateItem(
            context: android.content.Context,
            key: String,
            title: String?,
            text: String?,
            done: Int,
            total: Int,
        ) {
            if (!running) return
            val nm = context.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val id = itemId(key)
            items[key] = id
            val builder = Notification.Builder(context, CHANNEL_ID)
                .setContentTitle(title ?: NativeStrings.get(context, NativeStrings.DL_TITLE))
                .setContentText(text ?: "")
                .setSmallIcon(context.applicationInfo.icon)
                .setOnlyAlertOnce(true)
                .setGroup(GROUP)
                .setContentIntent(routeIntent(context, "mushaf"))
                .setTimeoutAfter(120_000)
            if (total > 0) builder.setProgress(total, done.coerceIn(0, total), false)
            nm.notify(id, builder.build())
            nm.notify(NOTIFICATION_ID, summary(context))
        }

        fun finishItem(context: android.content.Context, key: String) {
            val id = items.remove(key) ?: itemId(key)
            val nm = context.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(id)
            if (running) nm.notify(NOTIFICATION_ID, summary(context))
        }

        private fun cancelItems(context: android.content.Context) {
            val nm = context.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            for (id in items.values) nm.cancel(id)
            items.clear()
        }

        private fun summary(context: android.content.Context): Notification {
            val count = items.size
            return build(
                context,
                NativeStrings.get(context, NativeStrings.DL_TITLE),
                if (count > 0) "$count" else null,
                0,
                0,
            )
        }

        /** Rewrites the running service's notification with real progress. */
        fun update(context: android.content.Context, title: String?, text: String?, done: Int, total: Int) {
            if (!running) return
            val nm = context.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, build(context, title, text, done, total))
        }

        /**
         * A tap on one of this service's notifications, routed.
         *
         * «عايز لما أضغط على إشعار حاجة من التطبيق يروح للحاجة المتعلقة
         * بالإشعار … تحميل مصحف يروح مباشر لتحميل المصحف». These are the
         * app's own notifications, so unlike the downloader plugin's grouped
         * ones they can carry whatever we want — and the plugin's cannot: a
         * group notification's tap intent is built with an empty task string
         * and its handler skips it, which is why tapping one only ever
         * brought the app forward on whatever screen it was already on
         * (measured on emulator-5554, twice).
         *
         * The destination rides as an extra on the launcher intent;
         * `MainActivity.captureDownloadTap` reads it back. A distinct
         * requestCode per destination matters: `PendingIntent` equality
         * ignores extras, so two destinations sharing a code would collapse
         * into whichever was created first.
         */
        private fun routeIntent(context: android.content.Context, route: String): PendingIntent? {
            val openApp = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return null
            openApp.putExtra(EXTRA_ROUTE, route)
            return PendingIntent.getActivity(
                context, route.hashCode() and 0xffff, openApp,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        fun build(context: android.content.Context, title: String?, text: String?, done: Int, total: Int): Notification {
            val pendingIntent = routeIntent(context, "mushaf")
            val builder = Notification.Builder(context, CHANNEL_ID)
                .setContentTitle(title ?: NativeStrings.get(context, NativeStrings.DL_TITLE))
                .setContentText(text ?: NativeStrings.get(context, NativeStrings.DL_BODY))
                .setSmallIcon(context.applicationInfo.icon)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(pendingIntent)
                .setGroup(GROUP)
                .setGroupSummary(true)
            if (total > 0) builder.setProgress(total, done.coerceIn(0, total), false)
            return builder.build()
        }
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

    private fun buildNotification(title: String?): Notification =
        build(this, title, null, 0, 0)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                running = false
                cancelItems(this)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                ensureChannel()
                running = true
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

    override fun onDestroy() {
        running = false
        cancelItems(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
