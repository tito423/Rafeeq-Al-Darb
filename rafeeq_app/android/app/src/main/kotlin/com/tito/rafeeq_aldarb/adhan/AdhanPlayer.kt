package com.tito.rafeeq_aldarb.adhan

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * The one and only Adhan audio player — a process-wide `MediaPlayer` on the
 * **alarm** stream.
 *
 * Why native rather than `just_audio` (which the rest of the app uses):
 *
 *  1. `just_audio_background` replaces the global `JustAudioPlatform` and its
 *     `init()` throws *"just_audio_background supports only a single player
 *     instance"* for every player after the first. The app already spends
 *     that single slot on the Quran recitation player, so a second
 *     `AudioPlayer` for the adhan silently failed to load its source — which
 *     is exactly why the full-screen adhan and its preview came up mute.
 *  2. A prayer alarm has to sound when the app is dead. Dart isn't running
 *     then; only native code is.
 *
 * Preview and the real adhan both go through here, so "تجربة" tests the very
 * same audio path that fires at prayer time — not a lookalike.
 */
object AdhanPlayer {
    private const val TAG = "AdhanPlayer"

    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null

    /** Set while the user has hit "كتم" — volume 0 but still running. */
    @Volatile
    var isMuted: Boolean = false
        private set

    /** Called on the main thread when the recording reaches its end. */
    private var onCompletion: (() -> Unit)? = null

    val isPlaying: Boolean
        get() = try {
            player?.isPlaying == true
        } catch (_: IllegalStateException) {
            false
        }

    val positionMs: Int
        get() = try {
            player?.currentPosition ?: 0
        } catch (_: IllegalStateException) {
            0
        }

    val durationMs: Int
        get() = try {
            player?.duration?.takeIf { it > 0 } ?: 0
        } catch (_: IllegalStateException) {
            0
        }

    /**
     * Starts [spec]'s sound. Any sound already playing is stopped first, so
     * two adhans can never overlap.
     *
     * Returns false when the spec carries no playable sound or the source
     * could not be opened — the caller then still shows the alert, it just
     * has nothing to play.
     */
    @Synchronized
    fun start(context: Context, spec: AdhanSpec, onCompletion: (() -> Unit)? = null): Boolean {
        stop()
        if (!spec.hasSound) return false
        val value = spec.soundValue ?: return false

        this.onCompletion = onCompletion
        isMuted = false

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val mp = MediaPlayer()
        return try {
            mp.setAudioAttributes(attrs)
            when (spec.soundType) {
                AdhanSpec.SOUND_RAW -> {
                    val resId = context.resources.getIdentifier(
                        value, "raw", context.packageName,
                    )
                    if (resId != 0) {
                        context.resources.openRawResourceFd(resId).use { fd ->
                            mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                        }
                    } else if (!setFlutterAsset(context, mp, spec.assetPath)) {
                        // Neither source resolved: the raw resource is missing
                        // (a stripped release build) and there is no bundled
                        // asset to fall back to.
                        Log.w(TAG, "no playable source for raw '$value'")
                        mp.release()
                        return false
                    }
                }
                AdhanSpec.SOUND_URI -> mp.setDataSource(context, Uri.parse(value))
                AdhanSpec.SOUND_FILE -> mp.setDataSource(value)
                else -> {
                    mp.release()
                    return false
                }
            }
            mp.isLooping = false
            mp.setOnCompletionListener {
                // Hand the callback out before tearing down, so the UI can
                // dismiss itself on a natural end exactly as it does on Stop.
                val cb = this.onCompletion
                this.onCompletion = null
                cb?.invoke()
            }
            mp.setOnErrorListener { _, what, extra ->
                Log.w(TAG, "MediaPlayer error what=$what extra=$extra")
                stop()
                true
            }
            mp.prepare()
            requestFocus(context, attrs)
            mp.start()
            player = mp
            true
        } catch (e: Exception) {
            Log.w(TAG, "failed to start adhan sound (${spec.soundType}:$value)", e)
            try {
                mp.release()
            } catch (_: Exception) {
            }
            player = null
            abandonFocus()
            false
        }
    }

    /** "كتم" — silences the running adhan without ending the alert. */
    @Synchronized
    fun mute() {
        isMuted = true
        try {
            player?.setVolume(0f, 0f)
        } catch (_: IllegalStateException) {
        }
    }

    @Synchronized
    fun stop() {
        onCompletion = null
        isMuted = false
        val mp = player ?: run {
            abandonFocus()
            return
        }
        player = null
        try {
            if (mp.isPlaying) mp.stop()
        } catch (_: IllegalStateException) {
        }
        try {
            mp.reset()
        } catch (_: Exception) {
        }
        try {
            mp.release()
        } catch (_: Exception) {
        }
        abandonFocus()
    }

    /**
     * Plays the recording straight out of the Flutter asset bundle.
     *
     * The bundled adhans ship twice — as `res/raw/azanN.mp3` (what the native
     * player prefers) and as `assets/audio/adhan/azanN.mp3` inside
     * `flutter_assets` (what the app's own catalog lists). Flutter assets are
     * never touched by the Android resource shrinker, so this is the source
     * that cannot go missing, and it is why a stripped `res/raw` no longer
     * means a silent adhan.
     */
    private fun setFlutterAsset(
        context: Context,
        mp: MediaPlayer,
        assetPath: String?,
    ): Boolean {
        if (assetPath.isNullOrEmpty()) return false
        return try {
            context.assets.openFd("flutter_assets/$assetPath").use { fd ->
                mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            }
            true
        } catch (e: Exception) {
            Log.w(TAG, "flutter asset not playable: $assetPath", e)
            false
        }
    }

    /**
     * Ducks/pauses whatever else is playing for the duration of the adhan —
     * `TRANSIENT_EXCLUSIVE` is the focus type meant for alarms, and it also
     * makes the OS restore the user's music afterwards on its own.
     */
    private fun requestFocus(context: Context, attrs: AudioAttributes) {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        audioManager = am
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(attrs)
                .build()
            focusRequest = req
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
            )
        }
    }

    private fun abandonFocus() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
        focusRequest = null
        audioManager = null
    }
}
