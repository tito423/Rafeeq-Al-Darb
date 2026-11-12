package com.tito.rafeeq_aldarb

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.util.Log
import com.tito.rafeeq_aldarb.adhan.AdhanScheduler
import com.tito.rafeeq_aldarb.adhan.AdhanStorage
import org.json.JSONObject
import java.util.Locale

/**
 * THE CARD AND THE ADHAN FOLLOW THE PHONE, with the app closed.
 *
 * Owner, 2026-11-12: «لازم التطبيق يشتغل اوتو لاخر العمر … ديناميكية» - the
 * country he is in, no action from him. Run by [PrayerCardJob] before the
 * card's month is rebuilt. It only READS the location the phone already has
 * (`getLastKnownLocation`, no GPS of its own), so it costs nothing; a fix
 * more than [MOVE_METRES] from the stored place moves the card's inputs and
 * the adhan's calculation there and re-arms the adhan.
 *
 * A place the reader chose by hand (`manual_location_v1`) is never moved.
 * Without «السماح طوال الوقت» on Android 10+ the OS gives a background job
 * no location, and the stored place stays as it is.
 */
object LocationFollow {
    private const val MOVE_METRES = 10_000f

    /** Returns [args] with the new place, or [args] unchanged. */
    fun follow(ctx: Context, args: JSONObject): JSONObject {
        try {
            if (!AdhanStorage.unlocked(ctx) || !allowed(ctx) || manualPlace(ctx)) return args
            val fix = lastFix(ctx) ?: return args
            val inputs = JSONObject(args.optString("inputs", "{}"))
            if (!inputs.has("lat") || !inputs.has("lon")) return args
            val dist = FloatArray(1)
            Location.distanceBetween(
                inputs.getDouble("lat"), inputs.getDouble("lon"),
                fix.latitude, fix.longitude, dist,
            )
            if (dist[0] < MOVE_METRES) return args
            inputs.put("lat", fix.latitude).put("lon", fix.longitude)
            // The city in the card's language, or none: never a guessed name.
            val city = cityOf(ctx, fix, args.optString("locale", "ar")) ?: ""
            val moved = JSONObject(args.toString())
                .put("inputs", inputs.toString())
                .put("city", city)
            moveAdhan(ctx, fix)
            Log.i("LocationFollow", "moved ${dist[0].toInt()} m; card and adhan follow")
            return moved
        } catch (e: Exception) {
            Log.w("LocationFollow", "kept the stored place", e)
            return args
        }
    }

    private fun granted(ctx: Context, p: String) =
        ctx.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun allowed(ctx: Context): Boolean {
        val any = granted(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ||
            granted(ctx, Manifest.permission.ACCESS_COARSE_LOCATION)
        return any && (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            granted(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION))
    }

    private fun manualPlace(ctx: Context): Boolean {
        val raw = ctx.applicationContext
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.manual_location_v1", null)
        return !raw.isNullOrBlank() && raw != "null"
    }

    /**
     * The phone's newest fix. «Last known» only moves when something asked
     * for a fix, so when it is over [STALE_MS] old one fresh fix is asked
     * for (network first: cheap, no GPS), waiting at most [WAIT_MS]. Must
     * run off the main thread; the answer arrives on the main looper.
     */
    @Suppress("MissingPermission", "DEPRECATION")
    private fun lastFix(ctx: Context): Location? {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val known = lm.getProviders(true)
            .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
        if (known != null && System.currentTimeMillis() - known.time < STALE_MS) return known
        val provider = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
            .firstOrNull { runCatching { lm.isProviderEnabled(it) }.getOrDefault(false) }
            ?: return known
        val latch = java.util.concurrent.CountDownLatch(1)
        var fresh: Location? = null
        val listener = object : android.location.LocationListener {
            override fun onLocationChanged(l: Location) { fresh = l; latch.countDown() }
            override fun onStatusChanged(p: String?, s: Int, b: android.os.Bundle?) {}
            override fun onProviderEnabled(p: String) {}
            override fun onProviderDisabled(p: String) {}
        }
        return try {
            lm.requestSingleUpdate(provider, listener, android.os.Looper.getMainLooper())
            latch.await(WAIT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
            fresh ?: known
        } catch (_: Exception) {
            known
        } finally {
            runCatching { lm.removeUpdates(listener) }
        }
    }

    private const val STALE_MS = 6 * 60 * 60 * 1000L
    private const val WAIT_MS = 30_000L

    @Suppress("DEPRECATION")
    private fun cityOf(ctx: Context, fix: Location, locale: String): String? = try {
        if (!Geocoder.isPresent()) null
        else Geocoder(ctx, Locale(locale)).getFromLocation(fix.latitude, fix.longitude, 1)
            ?.firstOrNull()
            ?.let { it.locality ?: it.subAdminArea ?: it.adminArea }
    } catch (_: Exception) {
        null
    }

    /** The adhan's stored calculation moves too, and its alarms are re-armed. */
    private fun moveAdhan(ctx: Context, fix: Location) {
        val prefs = AdhanStorage.prefs(ctx)
        val raw = prefs.getString(AdhanStorage.CALCULATION, null) ?: return
        val calc = JSONObject(raw).put("lat", fix.latitude).put("lon", fix.longitude)
        prefs.edit().putString(AdhanStorage.CALCULATION, calc.toString()).commit()
        AdhanScheduler.rearmPersisted(ctx)
    }
}
