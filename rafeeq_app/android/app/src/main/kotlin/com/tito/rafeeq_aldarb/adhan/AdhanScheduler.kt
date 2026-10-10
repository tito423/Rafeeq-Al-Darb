package com.tito.rafeeq_aldarb.adhan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
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
    private const val KEY_CALCULATION = "calculation_v1"
    private var generation = 0L

    /**
     * Replaces the whole daily schedule with [specs] (one per prayer that
     * actually has an adhan). Returns true when the alarms were armed
     * *exactly*; false means the OS refused exact alarms and they were armed
     * approximately instead — the caller surfaces that to the user rather
     * than pretending the adhan is precise.
     */
    fun scheduleDaily(
        context: Context,
        specs: List<AdhanSpec>,
        calculation: Map<String, Any>?,
        targets: Map<String, Long>?,
    ): Boolean {
        if (calculation == null || targets == null || specs.any { targets[it.prayerKey] == null }) return false
        cancelDaily(context)
        generation++
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_CALCULATION, JSONObject(calculation).toString()).apply()
        val updated = specs.map { withTime(it, targets.getValue(it.prayerKey)) }
        persist(context, updated)
        var exact = true
        for (spec in updated) {
            if (!armAt(context, spec, targets.getValue(spec.prayerKey))) exact = false
        }
        if (updated.isEmpty()) AdhanRecomputeJob.cancel(context) else AdhanRecomputeJob.ensureScheduled(context)
        return exact
    }

    /**
     * Re-arms the whole schedule from inside [AdhanAlarmReceiver], right as
     * one of the alarms is firing. The one-minute floor matters: an alarm
     * that lands a few milliseconds *early* would otherwise compute "today"
     * as its own next occurrence and fire a second time seconds later.
     */
    fun rearmAfterFiring(context: Context, complete: (Boolean) -> Unit = {}) =
        recompute(context, System.currentTimeMillis() + 60_000L, complete)

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
        generation++
        AdhanRecomputeJob.cancel(context)
        val am = alarmManager(context) ?: return
        for (spec in load(context)) {
            am.cancel(operationFor(context, spec))
            am.cancel(operationFor(context, spec.copy(daily = false)))
        }
        persist(context, emptyList())
    }

    /** Re-arms everything after a reboot or an app update. */
    fun rearmPersisted(context: Context, complete: (Boolean) -> Unit = {}) =
        recompute(context, System.currentTimeMillis(), complete)

    private fun recompute(context: Context, floor: Long, complete: (Boolean) -> Unit) {
        val specs = load(context)
        if (specs.isEmpty()) {
            complete(true)
            return
        }
        val inputs = calculation(context) ?: AdhanCalculation.savedInputs(context)
        if (inputs == null) {
            Log.w(TAG, "cannot recalculate adhan without saved coordinates")
            complete(false)
            return
        }
        AdhanRecomputeJob.ensureScheduled(context)
        val requestGeneration = ++generation
        AdhanCalculation.compute(context, inputs, floor) { targets ->
            if (requestGeneration != generation) {
                complete(true) // A newer settings/time change already replaced this request.
            } else if (targets == null || specs.any { targets[it.prayerKey] == null }) {
                complete(false)
            } else {
                scheduleDaily(context, specs, inputs, targets)
                complete(true) // Approximate alarms still count as a completed calculation.
                Log.i(TAG, "recalculated ${specs.size} adhan targets from saved inputs")
            }
        }
    }

    private fun calculation(context: Context): Map<String, Any>? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_CALCULATION, null) ?: return null
        fun toMap(json: JSONObject): Map<String, Any> = json.keys().asSequence().associateWith { key ->
            val value = json.get(key)
            if (value is JSONObject) toMap(value) else value
        }
        return try { toMap(JSONObject(raw)) } catch (_: Exception) { null }
    }

    private fun withTime(spec: AdhanSpec, timestamp: Long): AdhanSpec {
        val time = Calendar.getInstance().apply { timeInMillis = timestamp }
        return spec.copy(hour = time.get(Calendar.HOUR_OF_DAY), minute = time.get(Calendar.MINUTE))
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
                /*
                 * `setAlarmClock`'s show-intent is the alarm's own UI: what
                 * the system opens from the alarm chip on the status bar or
                 * the lock screen. It pointed at MainActivity, so on a locked
                 * phone that route surfaced the app's last screen instead of
                 * the adhan. It is the adhan screen now, like every other
                 * path.
                 */
                val show = AdhanActivity.pendingIntent(context, spec)
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
