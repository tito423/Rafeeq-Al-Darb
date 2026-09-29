package com.tito.rafeeq_aldarb.adhan

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * The adhan's vibration: a single burst for the vibrate-only mode, and a
 * repeating one that lasts as long as a full-screen adhan when the user
 * turned «اهتزاز مع الأذان بالشاشة الكاملة» on. Tagged as an ALARM
 * vibration, like the sound on STREAM_ALARM, so a phone on silent still
 * vibrates for the adhan.
 */
object AdhanVibration {

    /** On 0.8 s, off 1.2 s, repeated from the start. */
    private val REPEATING = longArrayOf(0, 800, 1200)

    /** The vibrate-only mode's burst (unchanged from AdhanAlarmReceiver). */
    private val ONCE = longArrayOf(0, 700, 300, 700, 300, 700)

    fun once(context: Context) = play(context, ONCE, -1)

    /** Repeats until [stop]. */
    fun startRepeating(context: Context) = play(context, REPEATING, 0)

    fun stop(context: Context) {
        try {
            vibrator(context)?.cancel()
        } catch (_: Exception) {
        }
    }

    private fun play(context: Context, pattern: LongArray, repeat: Int) {
        val v = vibrator(context) ?: return
        if (!v.hasVibrator()) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                v.vibrate(
                    VibrationEffect.createWaveform(pattern, repeat),
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                v.vibrate(
                    VibrationEffect.createWaveform(pattern, repeat),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(pattern, repeat)
            }
        } catch (_: Exception) {
            // A vibration refused by the device is not worth losing the
            // adhan over.
        }
    }

    private fun vibrator(context: Context): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
}
