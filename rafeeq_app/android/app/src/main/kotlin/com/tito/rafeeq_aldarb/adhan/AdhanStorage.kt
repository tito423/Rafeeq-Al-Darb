package com.tito.rafeeq_aldarb.adhan

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.os.UserManager
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest

/** Only the alarm's inputs and selected sound may be read before first unlock. */
object AdhanStorage {
    private const val PREFS = "rafeeq_adhan_alarms"
    private const val MIGRATED = "device_storage_v1"
    const val ENTRIES = "daily_entries_v1"
    const val CALCULATION = "calculation_v1"
    private val prayers = setOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    fun unlocked(context: Context): Boolean =
        (context.getSystemService(Context.USER_SERVICE) as UserManager).isUserUnlocked

    fun device(context: Context): Context = if (context.isDeviceProtectedStorage) context
        else context.createDeviceProtectedStorageContext()

    /** This application's default storage remains credential-protected. */
    fun credential(context: Context): Context = context.applicationContext.also {
        check(!it.isDeviceProtectedStorage) { "Application storage must remain credential-protected" }
    }

    /** FlutterLoader calls getApplicationContext again; keep its cache in DE. */
    fun engineContext(context: Context): Context = object : ContextWrapper(device(context)) {
        override fun getApplicationContext(): Context = this
    }

    @Synchronized
    fun prefs(context: Context): SharedPreferences {
        val target = device(context).getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (target.getBoolean(MIGRATED, false) || !unlocked(context)) return target
        val credential = credential(context)
        val old = credential.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        try {
            val rows = JSONArray(old.getString(ENTRIES, "[]"))
            val specs = (0 until rows.length()).map { AdhanSpec.fromJson(rows.getJSONObject(it)) }
            val raw = old.getString(CALCULATION, null)
            val inputs = raw?.let { JSONObject(it) }
                ?: AdhanCalculation.savedInputs(credential)?.let { JSONObject(it) }
            val edit = target.edit().putString(ENTRIES, json(prepare(context, specs)))
                .putBoolean(MIGRATED, true)
            if (inputs != null) edit.putString(CALCULATION, minimal(inputs).toString())
            if (!edit.commit()) throw IllegalStateException("Cannot persist alarm migration")
        } catch (failure: Exception) {
            // Keep the original CE data and retry at the next unlocked re-arm.
            Log.w("AdhanStorage", "alarm migration could not finish", failure)
        }
        return target
    }

    /** Keep the old reader compatible without moving any unrelated preferences. */
    fun persist(context: Context, specs: List<AdhanSpec>, calculation: JSONObject? = null) {
        val target = prefs(context)
        val edit = target.edit().putString(ENTRIES, json(specs)).putBoolean(MIGRATED, true)
        if (calculation != null) edit.putString(CALCULATION, minimal(calculation).toString())
        if (!edit.commit()) throw IllegalStateException("Cannot persist alarm snapshot")
        if (unlocked(context)) {
            val old = credential(context).getSharedPreferences(PREFS, 0)
            val backup = old.edit().putString(ENTRIES, json(specs))
            if (calculation != null) backup.putString(CALCULATION, minimal(calculation).toString())
            if (!backup.commit()) Log.w("AdhanStorage", "cannot refresh legacy alarm snapshot")
        }
    }

    private fun minimal(inputs: JSONObject): JSONObject = JSONObject().apply {
        for (key in listOf("lat", "lon", "method", "madhab", "highLatitude")) {
            if (inputs.has(key)) put(key, inputs.get(key))
        }
        val offsets = inputs.optJSONObject("offsets")
        put("offsets", JSONObject().apply {
            for (key in prayers) if (offsets?.has(key) == true) put(key, offsets.get(key))
        })
    }

    private fun json(specs: List<AdhanSpec>): String = JSONArray().apply {
        for (spec in specs) put(spec.toJson())
    }.toString()

    /** Snapshot only selected custom recordings, never the user's whole library. */
    fun prepare(context: Context, specs: List<AdhanSpec>): List<AdhanSpec> = specs.map { spec ->
        if (!spec.hasSound || spec.soundType !in setOf(AdhanSpec.SOUND_FILE, AdhanSpec.SOUND_URI)) spec
        else spec.copy(soundType = AdhanSpec.SOUND_FILE, soundValue = copySound(context, spec))
    }

    private fun copySound(context: Context, spec: AdhanSpec): String {
        val base = device(context).filesDir.canonicalFile
        val dir = File(base, "adhan_audio").canonicalFile
        require(dir.parentFile == base) { "Adhan audio directory escapes device storage" }
        if (!dir.isDirectory && !dir.mkdirs()) throw IllegalStateException("Cannot create adhan audio directory")
        val value = requireNotNull(spec.soundValue)
        if (spec.soundType == AdhanSpec.SOUND_FILE) {
            val source = File(value).canonicalFile
            if (source.parentFile == dir && source.isFile) return source.path
        }
        val stream = if (spec.soundType == AdhanSpec.SOUND_URI)
            requireNotNull(context.contentResolver.openInputStream(android.net.Uri.parse(value)))
        else File(value).inputStream()
        return stream.use { input ->
            val stage = File.createTempFile("selected-", ".partial", dir)
            try {
                val digest = MessageDigest.getInstance("SHA-256")
                FileOutputStream(stage).use { output ->
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (count == 0) continue
                        output.write(buffer, 0, count)
                        digest.update(buffer, 0, count)
                    }
                    output.fd.sync()
                }
                val hash = digest.digest().joinToString("") { "%02x".format(it) }
                val target = File(dir, "$hash.audio")
                if (!stage.renameTo(target)) throw IllegalStateException("Cannot commit selected adhan audio")
                target.path
            } finally {
                stage.delete()
            }
        }
    }
}
