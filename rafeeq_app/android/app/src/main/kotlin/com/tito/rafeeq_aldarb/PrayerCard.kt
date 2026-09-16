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
import org.json.JSONArray

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
 * Dart stays the source of the content (`PrayerStatusNotification`): it sends
 * the whole schedule — every event of today and tomorrow, each already
 * written in the reader's language — and [post] decides from the clock which
 * one the card is on. The only way to remove the card is turning it off in
 * the app's settings.
 */
object PrayerCard {
    const val ID = 6100
    private const val CHANNEL_ID = "rafeeq_prayer_status"
    private const val PREFS = "rafeeq_prayer_card"
    const val ACTION_REPOST = "com.tito.rafeeq_aldarb.PRAYER_CARD_REPOST"
    const val ACTION_ROLLOVER = "com.tito.rafeeq_aldarb.PRAYER_CARD_ROLLOVER"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Fallback for the window Dart sends with every schedule. */
    private const val ELAPSED_WINDOW_MS = 60 * 60 * 1000L

    /**
     * Dart sends the WHOLE schedule — every prayer of today and tomorrow,
     * each with the two lines the card shows — and this works out from the
     * clock which one is current. It used to be sent one card plus its
     * successor, swapped by an alarm; that chain is two links long, and when
     * an alarm was batched away by Doze (`setAndAllowWhileIdle` is not exact)
     * the card simply froze. The owner photographed it at 06:06 still reading
     * «العشاء · ١٩:٤١» under the previous day's Hijri date.
     *
     * Recomputing on every post makes a missed alarm harmless, and the alarm
     * is exact now besides.
     */
    fun show(ctx: Context, eventsJson: String, elapsedMs: Long, title: String, body: String) {
        prefs(ctx).edit()
            .putBoolean("enabled", true)
            .putString("events", eventsJson)
            .putLong("elapsed_ms", if (elapsedMs > 0) elapsedMs else ELAPSED_WINDOW_MS)
            .putString("fallback_title", title)
            .putString("fallback_body", body)
            .apply()
        post(ctx)
    }

    fun hide(ctx: Context) {
        prefs(ctx).edit().putBoolean("enabled", false).apply()
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(broadcast(ctx, ACTION_ROLLOVER, 2))
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ID)
    }

    /** One event of the schedule: the two lines and the moment it happens. */
    private data class Event(val label: String, val body: String, val whenMs: Long)

    private fun events(ctx: Context): List<Event> {
        val raw = prefs(ctx).getString("events", null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Event(o.optString("label"), o.optString("body"), o.optLong("when"))
            }.sortedBy { it.whenMs }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** Posts the stored card, if the card is switched on. */
    fun post(ctx: Context) {
        val p = prefs(ctx)
        if (!p.getBoolean("enabled", false)) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(ctx, nm)

        val now = System.currentTimeMillis()
        val window = p.getLong("elapsed_ms", ELAPSED_WINDOW_MS)
        val all = events(ctx)
        // The event that has come in within the last hour wins: that hour
        // belongs to it and the card counts UP from it. Otherwise the next
        // one, counted DOWN to.
        val elapsed = all.lastOrNull { it.whenMs in (now - window)..now }
        val upcoming = all.firstOrNull { it.whenMs > now }
        val current = elapsed ?: upcoming
        val countDown = elapsed == null

        val title: String
        val text: String
        if (current != null) {
            title = current.body
            text = current.label
        } else {
            // No schedule yet (or it has run out): say so rather than show a
            // stale prayer.
            title = p.getString("fallback_title", "") ?: ""
            text = p.getString("fallback_body", "") ?: ""
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }
        builder
            .setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(text)
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
        // Android's chronometer is driven by elapsedRealtime while `when` is
        // wall-clock, so the platform converts once at post time - which is why
        // a card left up across a clock correction drifts and «بيقفز ثواني أو
        // بياخر ثواني». Every repost rebases it.
        val whenMs = current?.whenMs ?: 0L
        if (whenMs > 0) {
            builder.setWhen(whenMs).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setChronometerCountDown(countDown)
            }
        } else {
            builder.setShowWhen(false)
        }
        try {
            nm.notify(ID, builder.build())
        } catch (_: Exception) {
            // No notification permission: nothing to show, nothing to crash over.
        }

        // Wake exactly when this card stops being true: when the event comes
        // in, or when its hour is up and the next one takes over.
        val nextChange = when {
            current == null -> 0L
            countDown -> current.whenMs
            else -> current.whenMs + window
        }
        scheduleRollover(ctx, nextChange)
    }

    /** A rollover is just a repost: [post] works out what is current. */
    fun rollover(ctx: Context) = post(ctx)

    private fun scheduleRollover(ctx: Context, whenMs: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = broadcast(ctx, ACTION_ROLLOVER, 2)
        am.cancel(pi)
        if (whenMs <= System.currentTimeMillis()) return
        try {
            // EXACT, not `setAndAllowWhileIdle`: Doze batches an inexact alarm
            // (trap #32) and the card then tells the wrong time for as long as
            // the phone is idle, which is exactly when nobody is opening the
            // app to fix it. The app already holds SCHEDULE_EXACT_ALARM for the
            // adhan; where it has been refused, an inexact alarm is still
            // better than none because `post` re-derives everything anyway.
            val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                am.canScheduleExactAlarms()
            when {
                exact -> am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    am.setAndAllowWhileIdle(AlarmManager.RTC, whenMs, pi)
                else -> am.set(AlarmManager.RTC, whenMs, pi)
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
