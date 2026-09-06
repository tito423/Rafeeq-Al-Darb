package com.tito.rafeeq_aldarb.adhan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationManagerCompat

/**
 * The real BroadcastReceiver the exact alarm wakes.
 *
 * This is the entry point for every Adhan firing, and it runs natively —
 * no Flutter engine, no Dart isolate, so it works identically whether the
 * app is in the foreground, backgrounded, swiped away, or has never been
 * opened since the last reboot.
 *
 * What happens here is deliberately minimal and fast (a receiver gets ~10
 * seconds): re-arm tomorrow's alarm, then hand the firing to
 * [AdhanService] (for the two modes that make noise) or post the quiet
 * notification directly (for the two that do not).
 */
class AdhanAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ADHAN) return
        val spec = AdhanSpec.fromIntent(intent) ?: return
        Log.i(TAG, "adhan fired: ${spec.prayerKey} mode=${spec.mode} daily=${spec.daily}")

        // Re-arm tomorrow first. The app normally re-schedules the whole day
        // after each prayer-times fetch, but a phone that is never opened
        // must still call the adhan tomorrow, so the receiver owns its own
        // continuation rather than depending on the UI ever running.
        if (spec.daily) {
            AdhanScheduler.rearmAfterFiring(context)
        }

        when (spec.mode) {
            AdhanSpec.MODE_FULL, AdhanSpec.MODE_AUDIO -> AdhanService.fire(context, spec)
            AdhanSpec.MODE_VIBRATE -> {
                vibrate(context)
                postQuietAlert(context, spec)
            }
            else -> postQuietAlert(context, spec)
        }
    }

    /**
     * Vibrate and silent modes never make a sound and never take the screen,
     * so they need no service at all — a plain, dismissible notification is
     * the honest surface for them.
     */
    private fun postQuietAlert(context: Context, spec: AdhanSpec) {
        AdhanNotifications.ensureChannels(context)
        try {
            NotificationManagerCompat.from(context).notify(
                AdhanNotifications.NOTIFICATION_ID,
                AdhanNotifications.buildAlert(context, spec, muted = false),
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "POST_NOTIFICATIONS not granted - quiet adhan alert dropped", e)
        }
    }

    private fun vibrate(context: Context) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        } ?: return

        val pattern = longArrayOf(0, 700, 300, 700, 300, 700)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    companion object {
        private const val TAG = "AdhanAlarmReceiver"
        const val ACTION_ADHAN = "com.tito.rafeeq_aldarb.adhan.ALARM"
    }
}
