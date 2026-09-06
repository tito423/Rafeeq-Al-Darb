package com.tito.rafeeq_aldarb.adhan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.tito.rafeeq_aldarb.MainActivity
import org.json.JSONArray
import java.util.Calendar

/**
 * Arms the Adhan alarms with `AlarmManager.setAlarmClock` — deliberately the
 * *alarm-clock* API and not `setExactAndAllowWhileIdle`.
 *
 * `setAlarmClock` is the strongest scheduling primitive Android offers and
 * the only one that behaves like a real alarm app:
 *
 *  • it fires through Doze and app-standby buckets untouched;
 *  • the app receiving it gets a temporary exemption from the
 *    background-activity-start and background-foreground-service-start
 *    restrictions, which is precisely what lets [AdhanService] put
 *    [AdhanActivity] on screen over the lock screen on Android 10-15;
 *  • the OS shows the next one in the status bar, so the user can see the
 *    adhan really is armed.
 *
 * Every armed alarm is also persisted here, because `AlarmManager` forgets
 * everything on reboot — [AdhanBootReceiver] re-arms from this store.
 */
object AdhanScheduler {
    private const val TAG = "AdhanScheduler"
    private const val PREFS = "rafeeq_adhan_alarms"
    private const val KEY_ENTRIES = "daily_entries_v1"

    /**
     * Replaces the whole daily schedule with [specs] (one per prayer that
     * actually has an adhan). Returns true when the alarms were armed
     * *exactly*; false means the OS refused exact alarms and they were armed
     * approximately instead — the caller surfaces that to the user rather
     * than pretending the adhan is precise.
     */
    fun scheduleDaily(context: Context, specs: List<AdhanSpec>): Boolean {
        cancelDaily(context)
        persist(context, specs)
        var exact = true
        for (spec in specs) {
            if (!armAt(context, spec, nextOccurrence(spec.hour, spec.minute))) exact = false
        }
        return exact
    }

    /**
     * Re-arms the whole schedule from inside [AdhanAlarmReceiver], right as
     * one of the alarms is firing. The one-minute floor matters: an alarm
     * that lands a few milliseconds *early* would otherwise compute "today"
     * as its own next occurrence and fire a second time seconds later.
     */
    fun rearmAfterFiring(context: Context) {
        val specs = load(context)
        if (specs.isEmpty()) return
        val floor = System.currentTimeMillis() + 60_000L
        for (spec in specs) {
            armAt(context, spec, nextOccurrence(spec.hour, spec.minute, floor))
        }
    }

    /**
     * The "تجربة" button: fires [spec] once, [delayMs] from now, under its
     * own request code so it can never overwrite that prayer's real daily
     * alarm.
     */
    fun scheduleOneShot(context: Context, spec: AdhanSpec, delayMs: Long): Boolean {
        val oneShot = spec.copy(daily = false)
        return armAt(context, oneShot, System.currentTimeMillis() + delayMs)
    }

    fun cancelDaily(context: Context) {
        val am = alarmManager(context) ?: return
        for (spec in load(context)) {
            am.cancel(operationFor(context, spec))
        }
    }

    fun cancelAll(context: Context) {
        val am = alarmManager(context) ?: return
        for (spec in load(context)) {
            am.cancel(operationFor(context, spec))
            am.cancel(operationFor(context, spec.copy(daily = false)))
        }
        persist(context, emptyList())
    }

    /** Re-arms everything after a reboot or an app update. */
    fun rearmPersisted(context: Context) {
        val specs = load(context)
        if (specs.isEmpty()) return
        for (spec in specs) {
            armAt(context, spec, nextOccurrence(spec.hour, spec.minute))
        }
        Log.i(TAG, "re-armed ${specs.size} adhan alarms after boot")
    }

    fun canScheduleExact(context: Context): Boolean {
        val am = alarmManager(context) ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.canScheduleExactAlarms()
        } else {
            true
        }
    }

    // ── internals ────────────────────────────────────────────────────────

    private fun armAt(context: Context, spec: AdhanSpec, triggerAtMillis: Long): Boolean {
        val am = alarmManager(context) ?: return false
        val operation = operationFor(context, spec)
        return try {
            if (canScheduleExact(context)) {
                val show = PendingIntent.getActivity(
                    context,
                    spec.requestCode,
                    Intent(context, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, show), operation)
                true
            } else {
                // No SCHEDULE_EXACT_ALARM grant: arming approximately is far
                // better than not arming at all, and the settings screen
                // shows the user the one button that fixes it.
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
                false
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "exact alarm refused for ${spec.prayerKey}", e)
            try {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
            } catch (_: Exception) {
            }
            false
        }
    }

    private fun operationFor(context: Context, spec: AdhanSpec): PendingIntent {
        val intent = Intent(context, AdhanAlarmReceiver::class.java).also {
            it.action = AdhanAlarmReceiver.ACTION_ADHAN
            // A distinct data URI per prayer keeps the PendingIntents from
            // being treated as equal (extras are not part of that comparison).
            it.data = android.net.Uri.parse("rafeeq://adhan/${spec.prayerKey}/${spec.daily}")
            spec.writeTo(it)
        }
        return PendingIntent.getBroadcast(
            context,
            spec.requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextOccurrence(
        hour: Int,
        minute: Int,
        notBefore: Long = System.currentTimeMillis(),
    ): Long {
        val now = Calendar.getInstance().apply { timeInMillis = notBefore }
        val target = Calendar.getInstance().apply {
            timeInMillis = notBefore
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) target.add(Calendar.DAY_OF_YEAR, 1)
        return target.timeInMillis
    }

    private fun alarmManager(context: Context): AlarmManager? =
        context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

    private fun persist(context: Context, specs: List<AdhanSpec>) {
        val array = JSONArray()
        for (s in specs) array.put(s.toJson())
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ENTRIES, array.toString())
            .apply()
    }

    fun load(context: Context): List<AdhanSpec> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ENTRIES, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { AdhanSpec.fromJson(array.getJSONObject(it)) }
        } catch (e: Exception) {
            Log.w(TAG, "corrupt persisted adhan schedule", e)
            emptyList()
        }
    }
}
