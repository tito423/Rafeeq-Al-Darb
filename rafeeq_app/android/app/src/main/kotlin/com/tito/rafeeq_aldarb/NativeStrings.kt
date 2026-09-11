package com.tito.rafeeq_aldarb

import android.content.Context
import org.json.JSONObject

/**
 * The handful of strings **Android itself** renders, in the language the user
 * picked inside the app.
 *
 * Why not `values-<lang>/strings.xml`, the obvious Android answer? Because this
 * app's language is not the device's. It is chosen in Settings, stored by
 * `easy_localization` (`saveLocale: true`) and applied to a Flutter widget
 * tree; Android resources would follow the *system* locale instead, so a phone
 * set to English with the app set to Urdu would get English notifications while
 * every screen was Urdu. That is the same class of bug as the Adhan alert's
 * missing Urdu locale, arrived at from the other direction.
 *
 * So Dart is the single source of truth: `NativeStrings.sync()` (Dart) pushes
 * the already-translated strings here on startup and on every language change,
 * and they are kept in this app's own SharedPreferences file — readable from a
 * broadcast receiver or a service with no Flutter engine alive, which is
 * exactly the situation an alarm fires in.
 *
 * The fallbacks below are the Arabic these strings were hardcoded as, so a
 * first launch that fires an alarm before Dart has ever run degrades to what
 * shipped before rather than to a bare key.
 */
object NativeStrings {
    private const val PREFS = "rafeeq_native_strings"
    private const val KEY = "strings_v1"

    const val ADHAN_CHANNEL = "adhan_channel"
    const val ADHAN_CHANNEL_DESC = "adhan_channel_desc"
    const val ADHAN_CHANNEL_VIBRATE = "adhan_channel_vibrate"
    const val ADHAN_CHANNEL_VIBRATE_DESC = "adhan_channel_vibrate_desc"
    const val ADHAN_CHANNEL_SILENT = "adhan_channel_silent"
    const val ADHAN_CHANNEL_SILENT_DESC = "adhan_channel_silent_desc"

    /** Carries a single `%s`, replaced with the prayer's own name. */
    const val ADHAN_TITLE = "adhan_title"
    const val ADHAN_BODY = "adhan_body"
    const val ADHAN_BODY_MUTED = "adhan_body_muted"
    const val ADHAN_STOP = "adhan_stop"
    const val ADHAN_MUTE = "adhan_mute"

    const val DL_CHANNEL = "dl_channel"
    const val DL_CHANNEL_DESC = "dl_channel_desc"
    const val DL_TITLE = "dl_title"
    const val DL_BODY = "dl_body"
    const val PRAYER_CHANNEL = "prayer_channel"
    const val PRAYER_CHANNEL_DESC = "prayer_channel_desc"

    private val fallback = mapOf(
        ADHAN_CHANNEL to "الأذان",
        ADHAN_CHANNEL_DESC to "تنبيه الأذان عند دخول وقت الصلاة",
        ADHAN_CHANNEL_VIBRATE to "الأذان — اهتزاز فقط",
        ADHAN_CHANNEL_VIBRATE_DESC to "تنبيه بالاهتزاز فقط عند دخول وقت الصلاة",
        ADHAN_CHANNEL_SILENT to "الأذان — صامت",
        ADHAN_CHANNEL_SILENT_DESC to "تنبيه صامت عند دخول وقت الصلاة، بلا صوت أو اهتزاز",
        ADHAN_TITLE to "أذان صلاة %s",
        ADHAN_BODY to "الله أكبر، حان وقت الصلاة",
        ADHAN_BODY_MUTED to "مكتوم — الله أكبر، حان وقت الصلاة",
        ADHAN_STOP to "إيقاف",
        ADHAN_MUTE to "كتم",
        DL_CHANNEL to "تنزيل المحتوى في الخلفية",
        DL_CHANNEL_DESC to "يبقي التطبيق نشطًا أثناء تنزيل المحتوى في الخلفية",
        DL_TITLE to "جارٍ التنزيل",
        DL_BODY to "يتابع التطبيق التنزيل في الخلفية",
        PRAYER_CHANNEL to "الصلاة القادمة",
        PRAYER_CHANNEL_DESC to "بطاقة الصلاة القادمة مع العدّ التنازلي",
    )

    /** Called from Dart whenever the app language is set or changes. */
    fun sync(context: Context, values: Map<String, String>) {
        val json = JSONObject()
        for ((k, v) in values) if (v.isNotEmpty()) json.put(k, v)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, json.toString())
            .apply()
    }

    fun get(context: Context, key: String): String {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
        if (raw != null) {
            try {
                val stored = JSONObject(raw).optString(key, "")
                if (stored.isNotEmpty()) return stored
            } catch (_: Exception) {
                // A corrupt blob is not worth crashing an alarm over.
            }
        }
        return fallback[key] ?: key
    }
}
