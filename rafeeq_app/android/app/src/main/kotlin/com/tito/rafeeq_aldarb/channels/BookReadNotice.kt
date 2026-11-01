package com.tito.rafeeq_aldarb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import io.flutter.plugin.common.MethodChannel

/**
 * The book reader's notification, lock-screen card and headset button.
 *
 * The open voice plays through a plain MediaPlayer (VoicePlayerChannel), not
 * through just_audio, so nothing gave it the controls a listener expects
 * once the phone is in a pocket. This adds them with the framework's own
 * MediaSession and Notification.MediaStyle (API 21+, no extra library):
 * previous sentence, pause/play, next sentence, stop. Every press goes back
 * to Dart as `control` on the voice_player channel; the reading itself stays
 * in BookReadAloud.
 *
 * It lives on the APPLICATION context, created once: AudioServiceActivity
 * can be recreated (TRAPS 62), and a receiver or session tied to an old
 * activity would either leak or answer a dead engine. [channel] is the
 * engine's current channel, replaced on every registration.
 */
object BookReadNotice {
    private const val CHANNEL_ID = "book_reader"
    private const val NOTICE_ID = 4711
    private const val ACTION = "com.tito.rafeeq_aldarb.BOOK_READ_CONTROL"

    var channel: MethodChannel? = null
    private var session: MediaSession? = null
    private var receiver: BroadcastReceiver? = null

    private fun send(what: String) {
        channel?.invokeMethod("control", what)
    }

    private fun ensure(ctx: Context) {
        if (session != null) return
        val app = ctx.applicationContext
        session = MediaSession(app, "rafeeq_book_reader").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() = send("play")
                override fun onPause() = send("pause")
                override fun onSkipToNext() = send("next")
                override fun onSkipToPrevious() = send("previous")
                override fun onStop() = send("stop")
            })
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                i?.getStringExtra("what")?.let { send(it) }
            }
        }
        val filter = IntentFilter(ACTION)
        if (Build.VERSION.SDK_INT >= 33) {
            app.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            app.registerReceiver(r, filter)
        }
        receiver = r
    }

    private fun action(ctx: Context, what: String, code: Int): PendingIntent {
        val i = Intent(ACTION).setPackage(ctx.packageName).putExtra("what", what)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(ctx, code, i, flags)
    }

    @Suppress("DEPRECATION")
    fun show(ctx: Context, title: String, text: String, playing: Boolean, labels: Map<String, String>) {
        ensure(ctx)
        val app = ctx.applicationContext
        val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, labels["channel"] ?: "Book reader", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) }
            )
        }
        val s = session!!
        val actions = PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_STOP
        s.setPlaybackState(
            PlaybackState.Builder()
                .setActions(actions)
                .setState(if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, 0, 1f)
                .build()
        )
        s.isActive = true
        val open = app.packageManager.getLaunchIntentForPackage(app.packageName)?.let {
            it.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            PendingIntent.getActivity(app, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0))
        }
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(app, CHANNEL_ID) else Notification.Builder(app)
        b.setSmallIcon(app.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(playing)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .setDeleteIntent(action(app, "stop", 5))
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_previous, labels["previous"] ?: "Previous", action(app, "previous", 1)).build())
            .addAction(
                if (playing) Notification.Action.Builder(android.R.drawable.ic_media_pause, labels["pause"] ?: "Pause", action(app, "pause", 2)).build()
                else Notification.Action.Builder(android.R.drawable.ic_media_play, labels["play"] ?: "Play", action(app, "play", 2)).build()
            )
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_next, labels["next"] ?: "Next", action(app, "next", 3)).build())
            .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, labels["stop"] ?: "Stop", action(app, "stop", 4)).build())
            .setStyle(Notification.MediaStyle().setMediaSession(s.sessionToken).setShowActionsInCompactView(0, 1, 2))
        try {
            nm.notify(NOTICE_ID, b.build())
        } catch (e: SecurityException) {
            // Notifications refused by the user: the controls stay in the reader.
        }
    }

    fun hide(ctx: Context) {
        val nm = ctx.applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTICE_ID)
        session?.isActive = false
    }
}
