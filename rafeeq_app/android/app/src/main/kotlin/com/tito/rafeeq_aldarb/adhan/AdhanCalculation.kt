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
        val values = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).all
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
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            var engine: FlutterEngine? = null
            var completed = false
            lateinit var timeout: Runnable
            fun finish(targets: Map<String, Long>?) {
                if (completed) return
                completed = true
                handler.removeCallbacks(timeout)
                // Return outside a platform message before destroying its engine.
                handler.post {
                    engine?.destroy()
                    complete(targets)
                }
            }
            timeout = Runnable {
                Log.w("AdhanCalculation", "offline calculation timed out")
                finish(null)
            }
            handler.postDelayed(timeout, 8_000)
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context.applicationContext)
                loader.ensureInitializationComplete(context.applicationContext, null)
                val created = FlutterEngine(context.applicationContext, null, false)
                engine = created
                val channel = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL)
                channel.setMethodCallHandler { call, result ->
                    if (call.method != "ready") {
                        result.notImplemented()
                    } else {
                        result.success(null)
                        channel.invokeMethod("calculate", mapOf(
                            "calculation" to inputs,
                            "notBefore" to notBefore,
                            "dates" to dates(notBefore),
                        ), object : MethodChannel.Result {
                            override fun success(value: Any?) {
                                val raw = value as? Map<*, *> ?: return finish(null)
                                val targets = raw.entries.associate {
                                    (it.key as String) to (it.value as Number).toLong()
                                }
                                finish(targets)
                            }
                            override fun error(code: String, message: String?, details: Any?) {
                                Log.w("AdhanCalculation", "offline calculation failed: $code")
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
                Log.w("AdhanCalculation", "cannot start offline calculator", failure)
                finish(null)
            }
        }
    }
}
