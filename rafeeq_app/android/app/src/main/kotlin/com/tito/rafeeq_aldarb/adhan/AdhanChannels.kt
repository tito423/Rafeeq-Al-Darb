package com.tito.rafeeq_aldarb.adhan

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The two method channels the Adhan module speaks over, registered by both
 * `MainActivity` (the app proper: scheduling + the preview player) and
 * [AdhanActivity] (the alert screen: position polling, Stop, Mute).
 *
 * Registering the same handlers in both engines is what lets the alert
 * screen run in its own lightweight Dart entrypoint without duplicating a
 * line of logic — the native singletons ([AdhanPlayer], [AdhanService]) are
 * process-wide, so whichever engine asks gets the same truth.
 */
object AdhanChannels {
    /** Playback + the live state the alert screen syncs its subtitles to. */
    const val PLAYER = "com.tito.rafeeq_aldarb/adhan_player"

    /** Arming, cancelling and testing the alarms themselves. */
    const val ALARM = "com.tito.rafeeq_aldarb/adhan_alarm"

    /**
     * [isAlertHost] is true only for [AdhanActivity]. It gates the "close"
     * call: that means "dismiss the alert screen", and honouring it from
     * MainActivity would tear the whole app off the recents stack instead.
     */
    fun register(
        context: Context,
        engine: FlutterEngine,
        activity: Activity? = null,
        isAlertHost: Boolean = false,
    ) {
        val appContext = context.applicationContext

        MethodChannel(engine.dartExecutor.binaryMessenger, PLAYER).setMethodCallHandler { call, result ->
            when (call.method) {
                // The "تجربة" preview: plays the chosen adhan through the very
                // same native player a real firing uses, so what the owner
                // hears in settings is literally what the alarm will play.
                "preview" -> {
                    val spec = specFromCall(call.arguments)
                    if (spec == null) {
                        result.error("bad_args", "a sound spec is required", null)
                    } else {
                        result.success(AdhanPlayer.start(appContext, spec))
                    }
                }
                // Stops both surfaces at once: the preview player *and* a real
                // firing (whose service also owns the notification and the
                // wake lock). Harmless when neither is running.
                "stop" -> {
                    AdhanService.stop(appContext)
                    AdhanPlayer.stop()
                    result.success(null)
                }
                "mute" -> {
                    AdhanService.mute(appContext)
                    AdhanPlayer.mute()
                    result.success(null)
                }
                // Polled by the alert screen ~5x/second to place the karaoke
                // subtitles on the real playback position.
                "state" -> result.success(
                    mapOf(
                        "playing" to AdhanPlayer.isPlaying,
                        "muted" to AdhanPlayer.isMuted,
                        "positionMs" to AdhanPlayer.positionMs,
                        "durationMs" to AdhanPlayer.durationMs,
                        "firing" to (AdhanService.current != null),
                    ),
                )
                // Closes the alert Activity itself (the alert screen is its own
                // task, so Navigator.pop has nothing to pop back to).
                "close" -> {
                    if (isAlertHost) activity?.finishAndRemoveTask()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(engine.dartExecutor.binaryMessenger, ALARM).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDaily" -> {
                    val raw = call.argument<List<Map<String, Any?>>>("prayers").orEmpty()
                    val specs = raw.map { AdhanSpec.fromMap(it) }
                    result.success(AdhanScheduler.scheduleDaily(appContext, specs))
                }
                "scheduleTest" -> {
                    val spec = specFromCall(call.argument<Map<String, Any?>>("prayer"))
                    val delay = (call.argument<Number>("delaySeconds") ?: 8).toLong() * 1000L
                    if (spec == null) {
                        result.error("bad_args", "a prayer spec is required", null)
                    } else {
                        result.success(AdhanScheduler.scheduleOneShot(appContext, spec, delay))
                    }
                }
                "cancelAll" -> {
                    AdhanScheduler.cancelAll(appContext)
                    AdhanService.stop(appContext)
                    result.success(null)
                }
                "canScheduleExact" -> result.success(AdhanScheduler.canScheduleExact(appContext))
                /*
                 * The adhan plays on STREAM_ALARM (see AdhanPlayer's
                 * AudioAttributes) so it is heard when the phone is silent or
                 * in Do Not Disturb. That is deliberate, and it is also why
                 * the volume rocker does nothing to it: the rocker moves the
                 * media stream. The owner hit exactly that — «صوتهم مش بيعلى
                 * إلا لما أعلي صوت المنبه من الفون» — so the alarm stream is
                 * readable and settable from inside the app now, instead of
                 * sending him to the system settings and back.
                 */
                "alarmVolume" -> {
                    val am = appContext.getSystemService(Context.AUDIO_SERVICE)
                        as? AudioManager
                    if (am == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "current" to am.getStreamVolume(AudioManager.STREAM_ALARM),
                                "max" to am.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                            )
                        )
                    }
                }
                "setAlarmVolume" -> {
                    val am = appContext.getSystemService(Context.AUDIO_SERVICE)
                        as? AudioManager
                    val value = (call.argument<Number>("value") ?: 0).toInt()
                    if (am == null) {
                        result.success(false)
                    } else {
                        try {
                            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                            am.setStreamVolume(
                                AudioManager.STREAM_ALARM,
                                value.coerceIn(0, max),
                                0,
                            )
                            result.success(true)
                        } catch (e: SecurityException) {
                            // A Do Not Disturb policy can forbid this. Saying
                            // so is better than pretending the slider moved.
                            result.success(false)
                        }
                    }
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                .setData(Uri.parse("package:${appContext.packageName}"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            (activity ?: appContext).startActivity(intent)
                        } catch (_: Exception) {
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun specFromCall(arguments: Any?): AdhanSpec? {
        val map = arguments as? Map<*, *> ?: return null
        return try {
            AdhanSpec.fromMap(map)
        } catch (_: Exception) {
            null
        }
    }
}
