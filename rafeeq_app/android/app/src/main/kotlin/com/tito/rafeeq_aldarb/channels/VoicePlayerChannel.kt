package com.tito.rafeeq_aldarb

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Plays one WAV file the book reader's open voice synthesised, and answers
 * when it has finished.
 *
 * Why not just_audio: the app initialises just_audio_background, which
 * refuses a second live `AudioPlayer`, and the recitation service already
 * owns the one it allows. The reader only needs "play this file, tell me
 * when it ends, stop" — a plain MediaPlayer does exactly that.
 *
 * `play` completes with true when the file ended and false when `stop` (or
 * a newer `play`) cut it short, so the Dart loop knows whether to go on.
 */
fun MainActivity.registerVoicePlayerChannel(flutterEngine: FlutterEngine) {
    var player: MediaPlayer? = null
    var pending: MethodChannel.Result? = null

    fun finish(ok: Boolean) {
        val r = pending
        pending = null
        player?.release()
        player = null
        r?.success(ok)
    }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.VOICE_PLAYER).setMethodCallHandler { call, result ->
        when (call.method) {
            "play" -> {
                finish(false)
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("play", "no path", null)
                    return@setMethodCallHandler
                }
                try {
                    val mp = MediaPlayer()
                    mp.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    mp.setDataSource(path)
                    mp.setOnCompletionListener { if (player === mp) finish(true) }
                    mp.setOnErrorListener { _, what, extra ->
                        if (player === mp) {
                            val r = pending
                            pending = null
                            player?.release()
                            player = null
                            r?.error("play", "MediaPlayer error $what/$extra", null)
                        }
                        true
                    }
                    mp.prepare()
                    player = mp
                    pending = result
                    mp.start()
                } catch (e: Exception) {
                    result.error("play", e.message, null)
                }
            }
            "stop" -> {
                finish(false)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
