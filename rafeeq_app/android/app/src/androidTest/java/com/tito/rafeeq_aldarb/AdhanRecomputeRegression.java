package com.tito.rafeeq_aldarb;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import com.tito.rafeeq_aldarb.adhan.AdhanCalculation;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.TimeZone;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import kotlin.Unit;
import org.json.JSONArray;
import org.json.JSONObject;

/** Exercises the actual headless engine and native local-date selection. */
final class AdhanRecomputeRegression {
    static void run(Instrumentation runner) {
        TimeZone originalZone = TimeZone.getDefault();
        Bundle result = new Bundle();
        int code = Activity.RESULT_CANCELED;
        try (InputStream stream = runner.getContext().getAssets().open("adhan_recompute_cases.json")) {
            byte[] bytes = new byte[stream.available()];
            int read = stream.read(bytes);
            if (read != bytes.length) throw new AssertionError("Incomplete fixture");
            JSONArray cases = new JSONArray(new String(bytes, java.nio.charset.StandardCharsets.UTF_8));
            int count = 0;
            for (int i = 0; i < cases.length(); i++) {
                JSONObject row = cases.getJSONObject(i);
                if (!row.optBoolean("native")) continue;
                TimeZone.setDefault(TimeZone.getTimeZone(row.getString("zone")));
                CountDownLatch latch = new CountDownLatch(1);
                AtomicReference<Map<String, Long>> actual = new AtomicReference<>();
                AdhanCalculation.INSTANCE.compute(runner.getTargetContext(),
                    map(row.getJSONObject("calculation")), row.getLong("notBefore"), targets -> {
                        actual.set(targets);
                        latch.countDown();
                        return Unit.INSTANCE;
                    });
                if (!latch.await(12, TimeUnit.SECONDS)) throw new AssertionError("Engine timeout: " + row.getString("name"));
                if (actual.get() == null) throw new AssertionError("No targets: " + row.getString("name"));
                JSONObject expected = row.getJSONObject("expected");
                for (Iterator<String> keys = expected.keys(); keys.hasNext();) {
                    String prayer = keys.next();
                    Long value = actual.get().get(prayer);
                    if (value == null || value != expected.getLong(prayer)) {
                        throw new AssertionError(row.getString("name") + "/" + prayer + ": "
                            + value + " != " + expected.getLong(prayer));
                    }
                }
                count++;
            }
            if (count < 8) throw new AssertionError("Missing native day/DST fixtures");
            result.putString("stream", "PASS: " + count + " offline headless day/DST/method/offset cases");
            code = Activity.RESULT_OK;
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure);
        } finally {
            TimeZone.setDefault(originalZone);
        }
        runner.finish(code, result);
    }

    private static Map<String, Object> map(JSONObject json) throws Exception {
        Map<String, Object> result = new HashMap<>();
        for (Iterator<String> keys = json.keys(); keys.hasNext();) {
            String key = keys.next();
            Object value = json.get(key);
            result.put(key, value instanceof JSONObject ? map((JSONObject) value) : value);
        }
        return result;
    }
}
