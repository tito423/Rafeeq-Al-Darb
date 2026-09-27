package com.tito.rafeeq_aldarb

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * «رفيق» - one spoken command through Android's own SpeechRecognizer.
 *
 * Why not the speech_to_text package: its current release (7.5.0, checked on
 * pub.dev 2026-09-27) needs Flutter 3.44 and this app builds on 3.38.7. What
 * the assistant needs is small - listen once, give back the text - so it is
 * done here with no new dependency.
 *
 * `listen` completes with a map: {text} on a result, or {error: code} with
 * SpeechRecognizer's ERROR_* number. Partial text is sent back while the
 * person speaks as a `partial` call, so the sheet can show the words live.
 * `preferOffline` asks for the on-device model; whether the phone has an
 * Arabic one is the device's business, and is exactly what the Xiaomi test
 * must show.
 */
fun MainActivity.registerSpeechChannel(flutterEngine: FlutterEngine) {
    val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.SPEECH)
    var recognizer: SpeechRecognizer? = null
    var pending: MethodChannel.Result? = null

    fun finish(value: Map<String, Any?>) {
        val r = pending ?: return
        pending = null
        recognizer?.destroy()
        recognizer = null
        r.success(value)
    }

    channel.setMethodCallHandler { call, result ->
        when (call.method) {
            "available" -> result.success(
                mapOf(
                    "any" to SpeechRecognizer.isRecognitionAvailable(this),
                    "onDevice" to (Build.VERSION.SDK_INT >= 31 &&
                        SpeechRecognizer.isOnDeviceRecognitionAvailable(this)),
                ),
            )
            "listen" -> {
                // A newer listen supersedes an unanswered one.
                finish(mapOf("error" to SpeechRecognizer.ERROR_CLIENT))
                val lang = call.argument<String>("lang") ?: "ar-EG"
                val offline = call.argument<Boolean>("preferOffline") ?: false
                val sr = SpeechRecognizer.createSpeechRecognizer(this)
                recognizer = sr
                pending = result
                sr.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        channel.invokeMethod("ready", null)
                    }
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {
                        channel.invokeMethod("level", rmsdB.toDouble())
                    }
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    override fun onError(error: Int) {
                        finish(mapOf("error" to error))
                    }
                    override fun onResults(results: Bundle?) {
                        val all = results
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            .orEmpty()
                        finish(mapOf("text" to all.firstOrNull(), "alternatives" to all))
                    }
                    override fun onPartialResults(partial: Bundle?) {
                        val t = partial
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            ?.firstOrNull()
                        if (!t.isNullOrBlank()) channel.invokeMethod("partial", t)
                    }
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, offline)
                }
                sr.startListening(intent)
            }
            "stop" -> {
                recognizer?.stopListening()
                result.success(null)
            }
            "cancel" -> {
                recognizer?.cancel()
                finish(mapOf("error" to SpeechRecognizer.ERROR_CLIENT))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
