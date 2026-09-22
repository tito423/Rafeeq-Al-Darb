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
import android.widget.RemoteViews
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
    /** The card's first post this process: its fixed `when` (see [post]). */
    private var cardWhen = 0L

    const val ID = 6100
    private const val CHANNEL_ID = "rafeeq_prayer_status"
    private const val PREFS = "rafeeq_prayer_card"
    const val ACTION_REPOST = "com.tito.rafeeq_aldarb.PRAYER_CARD_REPOST"
    const val ACTION_ROLLOVER = "com.tito.rafeeq_aldarb.PRAYER_CARD_ROLLOVER"

    /**
     * «الصلاة القادمة» — skip the elapsed hour for one post.
     *
     * The hour after an adhan belongs to the prayer that came in, counting UP:
     * «لما يحين وقت الصلاة يبدأ يعد عدّاد تصاعدي … لحد ساعة». That is the
     * owner's own rule and it stays the default. But it is also why the card
     * reads «المغرب ٦:٢١» at 7:13 pm while Salatuk beside it reads «العشاء
     * ٠٧:٣٨ -24:25», which is what he was comparing when he asked for the
     * Salatuk shape. This button is the one tap that jumps the card forward;
     * the flag clears itself on the next rollover, so the rule is not changed,
     * only overridden on request.
     */
    const val ACTION_SHOW_NEXT = "com.tito.rafeeq_aldarb.PRAYER_CARD_NEXT"

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
    fun show(
        ctx: Context,
        eventsJson: String,
        elapsedMs: Long,
        title: String,
        body: String,
        openLabel: String,
        nextLabel: String,
    ) {
        prefs(ctx).edit()
            .putBoolean("enabled", true)
            .putString("events", eventsJson)
            .putLong("elapsed_ms", if (elapsedMs > 0) elapsedMs else ELAPSED_WINDOW_MS)
            .putString("fallback_title", title)
            .putString("fallback_body", body)
            // The button captions come from Dart, already in the reader's
            // language. Nothing here may invent user-visible words.
            .putString("open_label", openLabel)
            .putString("next_label", nextLabel)
            .remove("skip_elapsed")
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
        // `skip_elapsed` is «الصلاة القادمة» having been pressed: for this
        // one post the elapsed hour is ignored and the card jumps to what is
        // next. It is consumed here so the next rollover restores the rule.
        val skipElapsed = p.getBoolean("skip_elapsed", false)
        if (skipElapsed) p.edit().remove("skip_elapsed").apply()
        val elapsed = if (skipElapsed) null
            else all.lastOrNull { it.whenMs in (now - window)..now }
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
        // THE TWO ACTION BUTTONS. «عايز شكل الاشعار بتاعي تيبيكال نفس اشعار
        // صلاتك» — the visible gap beside Salatuk was that its card carries
        // two and ours carried none.
        val openLabel = p.getString("open_label", "") ?: ""
        val nextLabel = p.getString("next_label", "") ?: ""
        ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.let {
            if (openLabel.isNotEmpty()) {
                builder.addAction(
                    0, openLabel,
                    PendingIntent.getActivity(
                        ctx, ID + 1, it,
                        PendingIntent.FLAG_IMMUTABLE or
                            PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            }
        }
        // Only offered while the card is actually sitting on a prayer that
        // has already come in — otherwise it is already showing what is next
        // and the button would do nothing, which is worse than not being
        // there.
        if (nextLabel.isNotEmpty() && !countDown && upcoming != null) {
            builder.addAction(0, nextLabel, broadcast(ctx, ACTION_SHOW_NEXT, 3))
        }

        // Android's chronometer is driven by elapsedRealtime while `when` is
        // wall-clock, so the platform converts once at post time - which is why
        // a card left up across a clock correction drifts and «بيقفز ثواني أو
        // بياخر ثواني». Every repost rebases it.
        val whenMs = current?.whenMs ?: 0L
        if (whenMs > 0) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // «فيه عدادين في الإشعار». The custom body below carries the
                // countdown the owner reads (red, inline, like Salatuk); the
                // header chronometer beside the app name was a second copy of
                // it, one second apart. From N on only the body counts. The
                // `when` is the card's first post, fixed, so a repost does not
                // move the card among the other notifications either.
                builder.setWhen(cardWhen.takeIf { it > 0 }
                    ?: System.currentTimeMillis().also { cardWhen = it })
                    .setShowWhen(false)
            } else {
                // Before N there is no custom body: the header is the only
                // countdown there is, so it stays.
                builder.setWhen(whenMs).setShowWhen(true).setUsesChronometer(true)
            }

            // THE COUNTDOWN, WHERE IT CAN BE READ.
            //
            // The header chronometer above stays — it is what keeps the card
            // honest if the custom body is ever dropped by an OEM launcher —
            // but the platform puts it in the timestamp slot, past the app
            // name, where it reads as a clock. The owner's own screenshot
            // shows «52:34» sitting there unrecognised, and I misread it as a
            // clock too on the first pass. Salatuk draws its own inline, in
            // red, and that is the whole difference.
            //
            // DecoratedCustomViewStyle, not a fully custom notification: the
            // header, the icon and the action buttons stay the platform's, so
            // the card still looks like an Android notification on every OEM
            // skin. Only these two lines are ours.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // The direction of the language the card is WRITTEN in, not of
                // the phone: a RemoteViews layout otherwise follows the system
                // locale, and on an English phone reading the app in Arabic the
                // lines were thrown to opposite edges (2026-09-22).
                val layout = if (isRtl(title + text)) R.layout.prayer_card_rtl
                    else R.layout.prayer_card
                val body = RemoteViews(ctx.packageName, layout)
                body.setTextViewText(R.id.prayer_card_title, title)
                body.setTextViewText(R.id.prayer_card_text, text)
                body.setChronometer(
                    R.id.prayer_card_countdown,
                    // The Chronometer's base is elapsedRealtime, while
                    // `whenMs` is wall clock, so it is converted here on
                    // every post — the same rebasing the header one needs,
                    // and the reason a card left up across a clock change
                    // used to drift.
                    android.os.SystemClock.elapsedRealtime() +
                        (whenMs - System.currentTimeMillis()),
                    null,
                    true,
                )
                body.setChronometerCountDown(R.id.prayer_card_countdown, countDown)
                builder.setStyle(Notification.DecoratedCustomViewStyle())
                builder.setCustomContentView(body)
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

    /** Whether [s]'s first strong character is right-to-left (Arabic, Urdu). */
    private fun isRtl(s: String): Boolean {
        for (ch in s) {
            when (Character.getDirectionality(ch)) {
                Character.DIRECTIONALITY_RIGHT_TO_LEFT,
                Character.DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC -> return true
                Character.DIRECTIONALITY_LEFT_TO_RIGHT -> return false
            }
        }
        return false
    }

    /** A rollover is just a repost: [post] works out what is current. */
    fun rollover(ctx: Context) = post(ctx)

    /** «الصلاة القادمة»: one post that ignores the elapsed hour. */
    fun showNext(ctx: Context) {
        prefs(ctx).edit().putBoolean("skip_elapsed", true).apply()
        post(ctx)
    }

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
            PrayerCard.ACTION_SHOW_NEXT -> PrayerCard.showNext(context)
            else -> PrayerCard.post(context)
        }
    }
}
