package com.tito.rafeeq_aldarb.adhan

import android.content.Intent
import org.json.JSONObject

/**
 * Everything one Adhan firing needs, in one place.
 *
 * This is the single value that travels the whole pipeline: Dart builds it
 * when the prayer times are (re)scheduled, [AdhanScheduler] persists it and
 * hands it to `AlarmManager`, [AdhanAlarmReceiver] reads it back out of the
 * alarm Intent, [AdhanService] plays it, and [AdhanActivity] renders it. It
 * is deliberately flat/primitive so it survives an Intent, a JSON blob in
 * SharedPreferences (needed to re-arm after a reboot) and a Flutter route
 * string without any per-hop translation.
 */
data class AdhanSpec(
    /** `fajr` / `dhuhr` / `asr` / `maghrib` / `isha`. Also the alarm identity. */
    val prayerKey: String,
    /** Already-localized prayer name — the native layer never translates. */
    val prayerLabel: String,
    /** `full` | `audio` | `vibrate` | `silent` — mirrors Dart's `AdhanMode`. */
    val mode: String,
    /** `raw` (bundled res/raw name) | `uri` (content://) | `file` (abs path) | `none`. */
    val soundType: String,
    val soundValue: String?,
    /**
     * The same bundled recording as a Flutter asset path
     * (`assets/audio/adhan/azanN.mp3`), used as a fallback when the `raw`
     * resource cannot be resolved. Belt and braces against the resource
     * shrinker, which silently stripped `res/raw/azan*` from release builds
     * until `res/raw/keep.xml` was added. Null for a custom or silent adhan.
     */
    val assetPath: String?,
    val hour: Int,
    val minute: Int,
    /** False for a one-shot "تجربة" firing, which must not re-arm for tomorrow. */
    val daily: Boolean,
) {
    val isFullScreen: Boolean get() = mode == MODE_FULL
    val hasSound: Boolean get() = (mode == MODE_FULL || mode == MODE_AUDIO) && soundType != SOUND_NONE

    /** Stable per-prayer request code, so re-scheduling replaces rather than stacks. */
    val requestCode: Int
        get() {
            val base = when (prayerKey) {
                "fajr" -> 7001
                "dhuhr" -> 7002
                "asr" -> 7003
                "maghrib" -> 7004
                "isha" -> 7005
                else -> 7009
            }
            return if (daily) base else base + 100
        }

    fun toJson(): JSONObject = JSONObject().apply {
        put("prayerKey", prayerKey)
        put("prayerLabel", prayerLabel)
        put("mode", mode)
        put("soundType", soundType)
        put("soundValue", soundValue ?: JSONObject.NULL)
        put("assetPath", assetPath ?: JSONObject.NULL)
        put("hour", hour)
        put("minute", minute)
        put("daily", daily)
    }

    fun writeTo(intent: Intent): Intent = intent.apply {
        putExtra(EXTRA_PRAYER_KEY, prayerKey)
        putExtra(EXTRA_PRAYER_LABEL, prayerLabel)
        putExtra(EXTRA_MODE, mode)
        putExtra(EXTRA_SOUND_TYPE, soundType)
        putExtra(EXTRA_SOUND_VALUE, soundValue)
        putExtra(EXTRA_ASSET_PATH, assetPath)
        putExtra(EXTRA_HOUR, hour)
        putExtra(EXTRA_MINUTE, minute)
        putExtra(EXTRA_DAILY, daily)
    }

    companion object {
        const val MODE_FULL = "full"
        const val MODE_AUDIO = "audio"
        const val MODE_VIBRATE = "vibrate"
        const val MODE_SILENT = "silent"

        const val SOUND_RAW = "raw"
        const val SOUND_URI = "uri"
        const val SOUND_FILE = "file"
        const val SOUND_NONE = "none"

        const val EXTRA_PRAYER_KEY = "rafeeq.adhan.prayerKey"
        const val EXTRA_PRAYER_LABEL = "rafeeq.adhan.prayerLabel"
        const val EXTRA_MODE = "rafeeq.adhan.mode"
        const val EXTRA_SOUND_TYPE = "rafeeq.adhan.soundType"
        const val EXTRA_SOUND_VALUE = "rafeeq.adhan.soundValue"
        const val EXTRA_ASSET_PATH = "rafeeq.adhan.assetPath"
        const val EXTRA_HOUR = "rafeeq.adhan.hour"
        const val EXTRA_MINUTE = "rafeeq.adhan.minute"
        const val EXTRA_DAILY = "rafeeq.adhan.daily"

        fun fromIntent(intent: Intent): AdhanSpec? {
            val key = intent.getStringExtra(EXTRA_PRAYER_KEY) ?: return null
            return AdhanSpec(
                prayerKey = key,
                prayerLabel = intent.getStringExtra(EXTRA_PRAYER_LABEL) ?: key,
                mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_FULL,
                soundType = intent.getStringExtra(EXTRA_SOUND_TYPE) ?: SOUND_NONE,
                soundValue = intent.getStringExtra(EXTRA_SOUND_VALUE),
                assetPath = intent.getStringExtra(EXTRA_ASSET_PATH),
                hour = intent.getIntExtra(EXTRA_HOUR, 0),
                minute = intent.getIntExtra(EXTRA_MINUTE, 0),
                daily = intent.getBooleanExtra(EXTRA_DAILY, true),
            )
        }

        fun fromJson(o: JSONObject): AdhanSpec = AdhanSpec(
            prayerKey = o.getString("prayerKey"),
            prayerLabel = o.optString("prayerLabel", o.getString("prayerKey")),
            mode = o.optString("mode", MODE_FULL),
            soundType = o.optString("soundType", SOUND_NONE),
            soundValue = if (o.isNull("soundValue")) null else o.optString("soundValue"),
            assetPath = if (o.isNull("assetPath")) null else o.optString("assetPath"),
            hour = o.optInt("hour"),
            minute = o.optInt("minute"),
            daily = o.optBoolean("daily", true),
        )

        /** Builds one from the map Dart sends over the method channel. */
        fun fromMap(map: Map<*, *>): AdhanSpec = AdhanSpec(
            prayerKey = map["prayerKey"] as String,
            prayerLabel = map["prayerLabel"] as? String ?: (map["prayerKey"] as String),
            mode = map["mode"] as? String ?: MODE_FULL,
            soundType = map["soundType"] as? String ?: SOUND_NONE,
            soundValue = map["soundValue"] as? String,
            assetPath = map["assetPath"] as? String,
            hour = (map["hour"] as? Number)?.toInt() ?: 0,
            minute = (map["minute"] as? Number)?.toInt() ?: 0,
            daily = map["daily"] as? Boolean ?: true,
        )
    }
}
