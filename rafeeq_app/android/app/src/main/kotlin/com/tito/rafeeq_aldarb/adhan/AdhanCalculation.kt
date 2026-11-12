package com.tito.rafeeq_aldarb.adhan

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Calendar

/** Reuses the prayer card's offline Dart calculator without starting its UI. */
object AdhanCalculation {
    private const val CHANNEL = "com.tito.rafeeq_aldarb/adhan_recompute"
    private const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    fun dates(notBefore: Long): List<List<Int>> {
        val day = Calendar.getInstance().apply { timeInMillis = notBefore }
        day.add(Calendar.DAY_OF_MONTH, -1)
        return (0..3).map {
            val parts = listOf(day.get(Calendar.YEAR), day.get(Calendar.MONTH) + 1, day.get(Calendar.DAY_OF_MONTH))
            day.add(Calendar.DAY_OF_MONTH, 1)
            parts
        }
    }

    /** Backfills the minimal snapshot for installs with the old hour/minute store. */
    fun savedInputs(context: Context): Map<String, Any>? {
        if (!AdhanStorage.unlocked(context)) return null
        val credential = AdhanStorage.credential(context)
        val values = credential.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).all
        fun value(key: String): Any? = values["flutter.$key"]
        fun number(key: String): Double? {
            val raw = value(key)
            return if (raw is Number) raw.toDouble() else (raw as? String)?.removePrefix(DOUBLE_PREFIX)?.toDoubleOrNull()
        }
        val manual = try {
            (value("manual_location_v1") as? String)?.let { JSONObject(it) }
        } catch (_: Exception) { null }
        val lat = manual?.optDouble("lat") ?: number("location_cache_lat_v1") ?: return null
        val lon = manual?.optDouble("lon") ?: number("location_cache_lon_v1") ?: return null
        if (!lat.isFinite() || !lon.isFinite() || kotlin.math.abs(lat) > 90 || kotlin.math.abs(lon) > 180) return null
        return mapOf(
            "lat" to lat, "lon" to lon,
            "method" to ((value("adhan_calc_method_v1") as? Number)?.toInt() ?: 4),
            "madhab" to (value("prayer_asr_madhab_v1") as? String ?: "shafi"),
            "highLatitude" to (value("prayer_high_latitude_rule_v1") as? String ?: "twilight_angle"),
            "offsets" to listOf("fajr", "dhuhr", "asr", "maghrib", "isha").associateWith {
                (value("prayer_minute_offset_v1_$it") as? Number)?.toInt() ?: 0
            },
        )
    }

    fun compute(context: Context, inputs: Map<String, Any>, notBefore: Long, complete: (Map<String, Long>?) -> Unit) {
        run(context, "calculate", mapOf(
            "calculation" to inputs,
            "notBefore" to notBefore,
            "dates" to dates(notBefore),
        )) { value ->
            val raw = value as? Map<*, *>
            complete(raw?.entries?.associate { (it.key as String) to (it.value as Number).toLong() })
        }
    }

    /**
     * Starts the headless Dart entry, asks it [method] with [args] and hands
     * back its answer (null on any failure or after [timeoutMs]). Used for
     * the adhan instants and for the status card's month of events.
     */
    fun run(
        context: Context,
        method: String,
        args: Any?,
        timeoutMs: Long = 8_000,
        complete: (Any?) -> Unit,
    ) {
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            var engine: FlutterEngine? = null
            var completed = false
            lateinit var timeout: Runnable
            fun finish(value: Any?) {
                if (completed) return
                completed = true
                handler.removeCallbacks(timeout)
                // Return outside a platform message before destroying its engine.
                handler.post {
                    engine?.destroy()
                    complete(value)
                }
            }
            timeout = Runnable {
                Log.w("AdhanCalculation", "offline $method timed out")
                finish(null)
            }
            handler.postDelayed(timeout, timeoutMs)
            try {
                val engineContext = AdhanStorage.engineContext(context)
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(engineContext)
                loader.ensureInitializationComplete(engineContext, null)
                val created = FlutterEngine(engineContext, null, false)
                engine = created
                val channel = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL)
                channel.setMethodCallHandler { call, result ->
                    if (call.method != "ready") {
                        result.notImplemented()
                    } else {
                        result.success(null)
                        channel.invokeMethod(method, args, object : MethodChannel.Result {
                            override fun success(value: Any?) = finish(value)
                            override fun error(code: String, message: String?, details: Any?) {
                                Log.w("AdhanCalculation", "offline $method failed: $code $message")
                                finish(null)
                            }
                            override fun notImplemented() = finish(null)
                        })
                    }
                }
                created.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "adhanRecomputeMain"),
                )
            } catch (failure: Exception) {
                Log.w("AdhanCalculation", "cannot start offline $method", failure)
                finish(null)
            }
        }
    }
}
