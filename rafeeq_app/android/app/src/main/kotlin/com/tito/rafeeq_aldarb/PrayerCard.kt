package com.tito.rafeeq_aldarb

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * The next-prayer card with its live countdown, posted natively so it can
 * come back when it is swiped away.
 *
 * «خلّي دايمًا إشعار الصلاة القادمة بعدّاده شغّال حتى لو حذفته من الإشعارات
 * بالغلط». Since Android 14 a user can dismiss an ongoing notification and
 * even a foreground service's. flutter_local_notifications gives no way to
 * hear about that, so the card used to vanish until the app was next opened.
 * Posted here it carries a delete intent: a dismissal — one swipe or "clear
 * all" — is a broadcast to [PrayerCardReceiver], which posts it again from
 * what was stored. The countdown is the notification's own chronometer, so it
 * keeps ticking with the app closed.
 *
 * Dart stays the source of the content (`PrayerStatusNotification`): it
 * sends the current card and the one after it; the rollover alarm swaps them
 * at the prayer's time, and the app refreshes both whenever it runs. The only
 * way to remove the card is turning it off in the app's settings.
 */
object PrayerCard {
    const val ID = 6100
    private const val CHANNEL_ID = "rafeeq_prayer_status"
    private const val PREFS = "rafeeq_prayer_card"
    const val ACTION_REPOST = "com.tito.rafeeq_aldarb.PRAYER_CARD_REPOST"
    const val ACTION_ROLLOVER = "com.tito.rafeeq_aldarb.PRAYER_CARD_ROLLOVER"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun show(
        ctx: Context,
        title: String,
        body: String,
        whenMs: Long,
        nextTitle: String?,
        nextBody: String?,
        nextWhen: Long,
    ) {
        prefs(ctx).edit()
            .putBoolean("enabled", true)
            .putString("title", title)
            .putString("body", body)
            .putLong("when", whenMs)
            .putString("next_title", nextTitle)
            .putString("next_body", nextBody)
            .putLong("next_when", nextWhen)
            .apply()
        post(ctx)
        scheduleRollover(ctx, whenMs)
    }

    fun hide(ctx: Context) {
        prefs(ctx).edit().putBoolean("enabled", false).apply()
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(broadcast(ctx, ACTION_ROLLOVER, 2))
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ID)
    }

    /** Posts the stored card, if the card is switched on. */
    fun post(ctx: Context) {
        val p = prefs(ctx)
        if (!p.getBoolean("enabled", false)) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(ctx, nm)
        val whenMs = p.getLong("when", 0L)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }
        builder
            .setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle(p.getString("title", "") ?: "")
            .setContentText(p.getString("body", "") ?: "")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .setDeleteIntent(broadcast(ctx, ACTION_REPOST, 1))
        ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.let {
            builder.setContentIntent(
                PendingIntent.getActivity(
                    ctx, ID, it,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
            )
        }
        if (whenMs > System.currentTimeMillis()) {
            builder.setWhen(whenMs).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) builder.setChronometerCountDown(true)
        } else {
            builder.setShowWhen(false)
        }
        try {
            nm.notify(ID, builder.build())
        } catch (_: Exception) {
            // No notification permission: nothing to show, nothing to crash over.
        }
    }

    /** At the prayer's time the card moves on to the one after it. */
    fun rollover(ctx: Context) {
        val p = prefs(ctx)
        val nextWhen = p.getLong("next_when", 0L)
        val nextTitle = p.getString("next_title", null)
        if (nextWhen > p.getLong("when", 0L) && nextTitle != null) {
            p.edit()
                .putString("title", nextTitle)
                .putString("body", p.getString("next_body", "") ?: "")
                .putLong("when", nextWhen)
                .remove("next_title").remove("next_body").putLong("next_when", 0L)
                .apply()
        }
        post(ctx)
    }

    private fun scheduleRollover(ctx: Context, whenMs: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = broadcast(ctx, ACTION_ROLLOVER, 2)
        am.cancel(pi)
        if (whenMs <= System.currentTimeMillis()) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC, whenMs, pi)
            } else {
                am.set(AlarmManager.RTC, whenMs, pi)
            }
        } catch (_: Exception) {
            // The app refreshes the card whenever it runs.
        }
    }

    private fun broadcast(ctx: Context, action: String, code: Int): PendingIntent {
        val intent = Intent(ctx, PrayerCardReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(
            ctx, 7100 + code, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun ensureChannel(ctx: Context, nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            NativeStrings.get(ctx, NativeStrings.PRAYER_CHANNEL),
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = NativeStrings.get(ctx, NativeStrings.PRAYER_CHANNEL_DESC)
        channel.setShowBadge(false)
        channel.setSound(null, null)
        channel.enableVibration(false)
        nm.createNotificationChannel(channel)
    }
}

/** Dismissed, rolled over, rebooted, or updated: the card goes back up. */
class PrayerCardReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            PrayerCard.ACTION_ROLLOVER -> PrayerCard.rollover(context)
            else -> PrayerCard.post(context)
        }
    }
}
