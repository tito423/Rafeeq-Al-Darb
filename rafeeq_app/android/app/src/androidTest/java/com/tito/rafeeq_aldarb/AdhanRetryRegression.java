package com.tito.rafeeq_aldarb;

import android.app.Activity;
import android.app.Instrumentation;
import android.app.job.JobScheduler;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import com.tito.rafeeq_aldarb.adhan.AdhanScheduler;
import com.tito.rafeeq_aldarb.adhan.AdhanStorage;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import kotlin.Unit;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * A firing consumes its alarm. When the headless recalculation then fails,
 * a retry job must be pending; when it succeeds, none may be left behind.
 */
final class AdhanRetryRegression {
    private static final int RETRY_JOB_ID = 20261013;
    private static final String[] LOCATION_KEYS = {
        "flutter.manual_location_v1", "flutter.location_cache_lat_v1", "flutter.location_cache_lon_v1",
    };

    static void run(Instrumentation runner) {
        Context context = runner.getTargetContext();
        SharedPreferences alarms = AdhanStorage.INSTANCE.prefs(context);
        SharedPreferences legacy = AdhanStorage.INSTANCE.credential(context)
            .getSharedPreferences("rafeeq_adhan_alarms", Context.MODE_PRIVATE);
        SharedPreferences flutter = AdhanStorage.INSTANCE.credential(context)
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
        java.util.Map<String, ?> savedAlarms = alarms.getAll();
        java.util.Map<String, ?> savedLegacy = legacy.getAll();
        java.util.Map<String, ?> savedFlutter = flutter.getAll();
        JobScheduler jobs = (JobScheduler) context.getSystemService(Context.JOB_SCHEDULER_SERVICE);
        Bundle result = new Bundle();
        int code = Activity.RESULT_CANCELED;
        try {
            JSONObject spec = new JSONObject()
                .put("prayerKey", "fajr").put("prayerLabel", "fajr").put("mode", "silent")
                .put("soundType", "none").put("hour", 5).put("minute", 0).put("daily", true);
            String entries = new JSONArray().put(spec).toString();

            // Failure: a schedule exists but nothing to calculate it from.
            jobs.cancel(RETRY_JOB_ID);
            SharedPreferences.Editor clearFlutter = flutter.edit();
            for (String key : LOCATION_KEYS) clearFlutter.remove(key);
            if (!clearFlutter.commit()) throw new AssertionError("Cannot clear location");
            if (!legacy.edit().remove(AdhanStorage.CALCULATION).commit()) throw new AssertionError("Cannot clear CE");
            if (!alarms.edit().putString(AdhanStorage.ENTRIES, entries)
                .remove(AdhanStorage.CALCULATION).putBoolean("device_storage_v1", true).commit()) {
                throw new AssertionError("Cannot seed schedule");
            }
            Boolean failed = rearm(runner, context);
            if (!Boolean.FALSE.equals(failed)) throw new AssertionError("Expected failure, got " + failed);
            if (jobs.getPendingJob(RETRY_JOB_ID) == null) throw new AssertionError("No retry job after failure");

            // Success: real coordinates (Dubai) recalculate and no retry stays pending.
            jobs.cancel(RETRY_JOB_ID);
            JSONObject calculation = new JSONObject().put("lat", 25.2048).put("lon", 55.2708)
                .put("method", 4).put("madhab", "shafi").put("highLatitude", "twilight_angle")
                .put("offsets", new JSONObject());
            if (!alarms.edit().putString(AdhanStorage.CALCULATION, calculation.toString()).commit()) {
                throw new AssertionError("Cannot seed calculation");
            }
            Boolean succeeded = rearm(runner, context);
            if (!Boolean.TRUE.equals(succeeded)) throw new AssertionError("Expected success, got " + succeeded);
            if (jobs.getPendingJob(RETRY_JOB_ID) != null) throw new AssertionError("Retry left after success");

            result.putString("stream", "PASS: retry after failure, none after success\n");
            code = Activity.RESULT_OK;
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure + "\n");
        } finally {
            runner.runOnMainSync(() -> AdhanScheduler.INSTANCE.cancelAll(context));
            jobs.cancel(RETRY_JOB_ID);
            restore(alarms, savedAlarms);
            restore(legacy, savedLegacy);
            restore(flutter, savedFlutter);
        }
        runner.finish(code, result);
    }

    private static Boolean rearm(Instrumentation runner, Context context) throws InterruptedException {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<Boolean> outcome = new AtomicReference<>();
        runner.runOnMainSync(() -> AdhanScheduler.INSTANCE.rearmAfterFiring(context, success -> {
            outcome.set(success);
            latch.countDown();
            return Unit.INSTANCE;
        }));
        if (!latch.await(15, TimeUnit.SECONDS)) throw new AssertionError("Re-arm timed out");
        return outcome.get();
    }

    @SuppressWarnings("unchecked")
    private static void restore(SharedPreferences prefs, java.util.Map<String, ?> values) {
        SharedPreferences.Editor edit = prefs.edit().clear();
        for (java.util.Map.Entry<String, ?> entry : values.entrySet()) {
            Object value = entry.getValue();
            if (value instanceof String) edit.putString(entry.getKey(), (String) value);
            else if (value instanceof Boolean) edit.putBoolean(entry.getKey(), (Boolean) value);
            else if (value instanceof Integer) edit.putInt(entry.getKey(), (Integer) value);
            else if (value instanceof Long) edit.putLong(entry.getKey(), (Long) value);
            else if (value instanceof Float) edit.putFloat(entry.getKey(), (Float) value);
            else if (value instanceof java.util.Set) edit.putStringSet(entry.getKey(), (java.util.Set<String>) value);
        }
        edit.commit();
    }
}
