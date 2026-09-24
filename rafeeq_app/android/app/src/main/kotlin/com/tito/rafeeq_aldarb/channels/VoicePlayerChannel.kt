package com.tito.rafeeq_aldarb

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
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
 *
 * AUDIO FOCUS. It took none, so nothing could pause it: on emulator-5554
 * (2026-09-24) the Isha adhan (AdhanPlayer, TRANSIENT_EXCLUSIVE) and a page
 * being read aloud played at the same time, and the reading went on after
 * the adhan was stopped. It now holds focus across a page's chunks: a
 * transient loss (the adhan, a call) pauses it and the gain resumes it at
 * the same word, as the recitation does; a duck lowers it; a permanent
 * loss ends it like `stop`. Focus is let go shortly after the last chunk,
 * so another app is not left paused behind a reader that has finished.
 */
fun MainActivity.registerVoicePlayerChannel(flutterEngine: FlutterEngine) {
    var player: MediaPlayer? = null
    var pending: MethodChannel.Result? = null
    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val main = Handler(Looper.getMainLooper())
    var focusRequest: AudioFocusRequest? = null
    var holdsFocus = false
    var pausedByFocus = false
    lateinit var onFocus: AudioManager.OnAudioFocusChangeListener

    fun abandonFocus() {
        if (!holdsFocus) return
        holdsFocus = false
        pausedByFocus = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(onFocus)
        }
    }

    val releaseIfIdle = Runnable { if (player == null) abandonFocus() }

    fun finish(ok: Boolean) {
        val r = pending
        pending = null
        player?.release()
        player = null
        r?.success(ok)
        // The next chunk normally follows within milliseconds; only a
        // reader that has really finished gives the focus back.
        main.removeCallbacks(releaseIfIdle)
        main.postDelayed(releaseIfIdle, 1500)
    }

    onFocus = AudioManager.OnAudioFocusChangeListener { change ->
        val mp = player
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // Set even between chunks, so the next one waits too.
                pausedByFocus = true
                if (mp != null && mp.isPlaying) mp.pause()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> mp?.setVolume(0.3f, 0.3f)
            AudioManager.AUDIOFOCUS_GAIN -> {
                mp?.setVolume(1f, 1f)
                if (pausedByFocus && mp != null && !mp.isPlaying) mp.start()
                pausedByFocus = false
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                holdsFocus = false
                pausedByFocus = false
                finish(false)
            }
        }
    }

    fun requestFocus() {
        main.removeCallbacks(releaseIfIdle)
        if (holdsFocus) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener(onFocus, main)
                .build()
            focusRequest = req
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(onFocus, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
        // Not granted (a call in progress): it plays as it always did
        // rather than wait for a gain that may never come.
        holdsFocus = granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
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
                    requestFocus()
                    // Mid-adhan: this chunk waits for the focus to return.
                    if (!pausedByFocus) mp.start()
                } catch (e: Exception) {
                    result.error("play", e.message, null)
                }
            }
            "stop" -> {
                finish(false)
                main.removeCallbacks(releaseIfIdle)
                abandonFocus()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
