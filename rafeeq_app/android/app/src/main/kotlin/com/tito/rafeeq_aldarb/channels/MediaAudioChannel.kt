package com.tito.rafeeq_aldarb

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tito.rafeeq_aldarb.adhan.AdhanNotifications

/**
 * Every audio file Android’s own media index knows about, for the Qur’an
 * player’s «ملفات الجهاز».
 *
 * Split out of MainActivity.configureFlutterEngine, which registered six
 * channels in one 304-line function. An extension function, so `this` is
 * still the activity and the handler moved verbatim.
 */
fun MainActivity.registerMediaAudioChannel(flutterEngine: FlutterEngine) {
    // Every audio file Android's media index knows about, for the Qur'an
    // player's «ملفات الجهاز». Read off MediaStore rather than by walking
    // the file system: it is the index the phone's own music apps use, it
    // already carries title, artist and album, and on Android 11+ it is the
    // only honest way to see other apps' files.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Channels.MEDIA_AUDIO).setMethodCallHandler { call, result ->
        if (call.method != "scan") {
            result.notImplemented()
            return@setMethodCallHandler
        }
        Thread {
            val out = ArrayList<Map<String, Any?>>()
            try {
                val uri = android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                val cols = mutableListOf(
                    android.provider.MediaStore.Audio.Media._ID,
                    android.provider.MediaStore.Audio.Media.TITLE,
                    android.provider.MediaStore.Audio.Media.ARTIST,
                    android.provider.MediaStore.Audio.Media.ALBUM,
                    android.provider.MediaStore.Audio.Media.DURATION,
                    android.provider.MediaStore.Audio.Media.SIZE,
                    android.provider.MediaStore.Audio.Media.DISPLAY_NAME,
                )
                val modern = android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q
                @Suppress("DEPRECATION")
                cols.add(if (modern) android.provider.MediaStore.Audio.Media.RELATIVE_PATH else android.provider.MediaStore.Audio.Media.DATA)
                contentResolver.query(
                    uri, cols.toTypedArray(),
                    "${android.provider.MediaStore.Audio.Media.DURATION} >= ?", arrayOf("5000"),
                    "${android.provider.MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
                )?.use { c ->
                    while (c.moveToNext()) {
                        val id = c.getLong(0)
                        val where = c.getString(7) ?: ""
                        val folder = where.trimEnd('/').let {
                            if (modern) it.substringAfterLast('/') else it.substringBeforeLast('/').substringAfterLast('/')
                        }
                        out.add(mapOf(
                            "id" to id,
                            "uri" to android.content.ContentUris.withAppendedId(uri, id).toString(),
                            "title" to (c.getString(1) ?: c.getString(6) ?: ""),
                            "artist" to c.getString(2),
                            "album" to c.getString(3),
                            "duration" to c.getLong(4),
                            "size" to c.getLong(5),
                            "folder" to folder,
                        ))
                    }
                }
                runOnUiThread { result.success(out) }
            } catch (e: Exception) {
                runOnUiThread { result.error("scan", e.message, null) }
            }
        }.start()
    }
}
