package com.tito.rafeeq_aldarb

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * «رفيق»'s view of the phone, so it never gets in anyone's way (owner,
 * 2026-09-27: «خد بالك من الكونفلكت مع الباقيين ومع الصوت في التطبيق ولما
 * تيجي مكالمة وفي النوتيفكيشن، في كل الحالات»):
 *
 *  - `busy`: {call, playing, recording} - a phone or internet call (the
 *    audio mode leaves NORMAL for ringing and calls), any sound playing on
 *    the phone (this app's recitation or adhan, another app's music), and
 *    how many recordings are open. The Dart side listens only when all are
 *    quiet, so a call, a notification sound or music is never fought over.
 *  - `startService` / `stopService`: the background listening service.
 *  - `stoppedByUser`: whether «إيقاف» in its notification was pressed.
 *  - `toFront`: brings the app forward for a command said in the
 *    background (Android may refuse; the command has still run).
 */
fun MainActivity.registerAssistantChannel(flutterEngine: FlutterEngine) {
    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.ASSISTANT)
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "busy" -> {
                    val mode = am.mode
                    val recording = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        am.activeRecordingConfigurations.size
                    } else 0
                    result.success(
                        mapOf(
                            "call" to (mode != AudioManager.MODE_NORMAL),
                            "playing" to am.isMusicActive,
                            "recording" to recording,
                        ),
                    )
                }
                "startService" -> {
                    AssistantListenService.stoppedByUser = false
                    AssistantListenService.start(
                        this,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("text") ?: "",
                        call.argument<String>("stop") ?: "",
                        call.argument<String>("channel") ?: "",
                    )
                    result.success(null)
                }
                "stopService" -> {
                    AssistantListenService.stop(this)
                    result.success(null)
                }
                "stoppedByUser" -> {
                    val v = AssistantListenService.stoppedByUser
                    AssistantListenService.stoppedByUser = false
                    result.success(v)
                }
                // Over other apps (owner, 2026-09-29): see AssistantOverlay.
                "overlayCan" -> result.success(AssistantOverlay.canDraw(applicationContext))
                "overlayRequest" -> {
                    try {
                        startActivity(AssistantOverlay.settingsIntent(applicationContext))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "overlayShow" -> {
                    AssistantOverlay.show(
                        applicationContext,
                        call.argument<String>("text") ?: "",
                        call.argument<Int>("seconds") ?: 4,
                        call.argument<Boolean>("rtl") ?: true,
                    )
                    result.success(null)
                }
                "overlayHide" -> {
                    AssistantOverlay.hide()
                    result.success(null)
                }
                "toFront" -> {
                    try {
                        // From the application context: with «Display over
                        // other apps» granted Android lets this through from
                        // the background; without it, it is refused and the
                        // command has still run.
                        applicationContext.startActivity(
                            Intent(applicationContext, MainActivity::class.java)
                                .addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
}
