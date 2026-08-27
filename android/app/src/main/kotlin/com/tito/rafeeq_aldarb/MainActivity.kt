package com.tito.rafeeq_aldarb

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.tito.rafeeq_aldarb/salatuk_notification"
    private val NOTIFICATION_CHANNEL_ID = "live_prayer_channel"
    private val NOTIFICATION_ID = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateNotification") {
                val nextPrayerName = call.argument<String>("nextPrayerName") ?: ""
                val nextPrayerTimeMs = call.argument<Long>("nextPrayerTimeMs") ?: 0L
                val times = call.argument<List<String>>("times") ?: listOf("00:00","00:00","00:00","00:00","00:00","00:00")
                val activeIndex = call.argument<Int>("activeIndex") ?: 0

                showCustomNotification(nextPrayerName, nextPrayerTimeMs, times, activeIndex)
                result.success(null)
            } else if (call.method == "cancelNotification") {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(NOTIFICATION_ID)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun showCustomNotification(nextPrayerName: String, nextPrayerTimeMs: Long, times: List<String>, activeIndex: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "الصلاة القادمة",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "عرض الصلاة القادمة والوقت المتبقي لها"
            channel.setShowBadge(false)
            notificationManager.createNotificationChannel(channel)
        }

        val remoteViews = RemoteViews(packageName, R.layout.notification_salatuk)

        // Set Top Row
        remoteViews.setTextViewText(R.id.tv_next_prayer_label, "الصلاة القادمة: $nextPrayerName")
        
        // Setup Chronometer
        remoteViews.setChronometer(R.id.chronometer, nextPrayerTimeMs, "باقي %s", true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            remoteViews.setChronometerCountDown(R.id.chronometer, true)
        }

        // Set Bottom Row Times
        if (times.size >= 6) {
            remoteViews.setTextViewText(R.id.tv_time_fajr, times[0])
            remoteViews.setTextViewText(R.id.tv_time_sunrise, times[1])
            remoteViews.setTextViewText(R.id.tv_time_dhuhr, times[2])
            remoteViews.setTextViewText(R.id.tv_time_asr, times[3])
            remoteViews.setTextViewText(R.id.tv_time_maghrib, times[4])
            remoteViews.setTextViewText(R.id.tv_time_isha, times[5])
        }

        // Reset highlights
        val activeColor = Color.parseColor("#FFD700") // Gold
        val inactiveColor = Color.parseColor("#AAAAAA")

        val nameIds = arrayOf(R.id.tv_name_fajr, R.id.tv_name_sunrise, R.id.tv_name_dhuhr, R.id.tv_name_asr, R.id.tv_name_maghrib, R.id.tv_name_isha)
        val timeIds = arrayOf(R.id.tv_time_fajr, R.id.tv_time_sunrise, R.id.tv_time_dhuhr, R.id.tv_time_asr, R.id.tv_time_maghrib, R.id.tv_time_isha)
        val containerIds = arrayOf(R.id.container_fajr, R.id.container_sunrise, R.id.container_dhuhr, R.id.container_asr, R.id.container_maghrib, R.id.container_isha)

        for (i in 0 until 6) {
            remoteViews.setTextColor(nameIds[i], inactiveColor)
            remoteViews.setTextColor(timeIds[i], inactiveColor)
            remoteViews.setInt(containerIds[i], "setBackgroundColor", Color.TRANSPARENT)
        }

        // Highlight active prayer
        if (activeIndex in 0..5) {
            remoteViews.setTextColor(nameIds[activeIndex], activeColor)
            remoteViews.setTextColor(timeIds[activeIndex], activeColor)
            remoteViews.setInt(containerIds[activeIndex], "setBackgroundColor", Color.parseColor("#33FFD700"))
        }

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(remoteViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
