package com.tito.rafeeq_aldarb.adhan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.tito.rafeeq_aldarb.MainActivity
import com.tito.rafeeq_aldarb.NativeStrings
import com.tito.rafeeq_aldarb.R

/**
 * The Adhan's notification surface: the channels it can post on, and the
 * one alert notification the foreground service wears.
 *
 * The channels carry **no sound of their own** — [AdhanPlayer] owns the
 * audio. A channel sound would double the adhan and could not be stopped by
 * the "إيقاف" button (a channel's sound is the OS's, not the app's).
 */
object AdhanNotifications {
    /** Bumped suffix on purpose: a channel's importance/sound is immutable once created. */
    const val CHANNEL_ALERT = "rafeeq_adhan_alert_v2"
    const val CHANNEL_VIBRATE = "rafeeq_adhan_vibrate_v2"
    const val CHANNEL_SILENT = "rafeeq_adhan_silent_v2"

    /** Every Adhan alert posts under this single id — one adhan at a time. */
    const val NOTIFICATION_ID = 7301

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val alert = NotificationChannel(
            CHANNEL_ALERT,
            NativeStrings.get(context, NativeStrings.ADHAN_CHANNEL),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = NativeStrings.get(context, NativeStrings.ADHAN_CHANNEL_DESC)
            setSound(null, null)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 400, 500)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
        }
        val vibrate = NotificationChannel(
            CHANNEL_VIBRATE,
            NativeStrings.get(context, NativeStrings.ADHAN_CHANNEL_VIBRATE),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description =
                NativeStrings.get(context, NativeStrings.ADHAN_CHANNEL_VIBRATE_DESC)
            setSound(null, null)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 600, 300, 600)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val silent = NotificationChannel(
            CHANNEL_SILENT,
            NativeStrings.get(context, NativeStrings.ADHAN_CHANNEL_SILENT),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description =
                NativeStrings.get(context, NativeStrings.ADHAN_CHANNEL_SILENT_DESC)
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(alert)
        nm.createNotificationChannel(vibrate)
        nm.createNotificationChannel(silent)
    }

    fun channelFor(spec: AdhanSpec): String = when (spec.mode) {
        AdhanSpec.MODE_VIBRATE -> CHANNEL_VIBRATE
        AdhanSpec.MODE_SILENT -> CHANNEL_SILENT
        else -> CHANNEL_ALERT
    }

    /**
     * The alert itself. For [AdhanSpec.MODE_FULL] it carries a
     * `fullScreenIntent` at [AdhanActivity] — the OS's own "this is an
     * incoming call / alarm, put it on screen now" signal — plus real Stop
     * and Mute actions wired straight to [AdhanService], so they act on the
     * native player instantly instead of waiting for a Dart isolate.
     */
    fun buildAlert(context: Context, spec: AdhanSpec, muted: Boolean): Notification {
        ensureChannels(context)

        val stop = servicePendingIntent(context, spec, AdhanService.ACTION_STOP, 1)
        val mute = servicePendingIntent(context, spec, AdhanService.ACTION_MUTE, 2)

        val contentIntent = if (spec.isFullScreen) {
            AdhanActivity.pendingIntent(context, spec)
        } else {
            PendingIntent.getActivity(
                context,
                3,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val builder = NotificationCompat.Builder(context, channelFor(spec))
            .setSmallIcon(R.mipmap.ic_launcher)
            // The title carries a single %s for the prayer's own name, so a
            // language whose word order differs from Arabic's can place it
            // where that language actually puts it.
            .setContentTitle(
                NativeStrings.get(context, NativeStrings.ADHAN_TITLE)
                    .replace("%s", spec.prayerLabel)
            )
            .setContentText(
                NativeStrings.get(
                    context,
                    if (muted) NativeStrings.ADHAN_BODY_MUTED else NativeStrings.ADHAN_BODY,
                )
            )
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // Neither the channel nor the notification makes a sound: the
            // adhan is AdhanPlayer's, and the vibrate mode buzzes explicitly
            // from AdhanAlarmReceiver. Anything else would double up, and a
            // channel sound in particular could not be stopped by "إيقاف".
            .setSound(null)
            .setVibrate(null)
            .setContentIntent(contentIntent)

        if (spec.hasSound) {
            // A sounding adhan is an ongoing alert the user must dismiss on
            // purpose; the quiet modes are ordinary, swipeable reminders.
            builder.setOngoing(true).setAutoCancel(false)
            builder.addAction(0, NativeStrings.get(context, NativeStrings.ADHAN_STOP), stop)
            if (!muted) {
                builder.addAction(0, NativeStrings.get(context, NativeStrings.ADHAN_MUTE), mute)
            }
        } else {
            builder.setOngoing(false).setAutoCancel(true)
        }

        if (spec.isFullScreen) {
            builder.setFullScreenIntent(AdhanActivity.pendingIntent(context, spec), true)
        }

        return builder.build()
    }

    private fun servicePendingIntent(
        context: Context,
        spec: AdhanSpec,
        action: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, AdhanService::class.java).also {
            it.action = action
            spec.writeTo(it)
        }
        return PendingIntent.getService(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
