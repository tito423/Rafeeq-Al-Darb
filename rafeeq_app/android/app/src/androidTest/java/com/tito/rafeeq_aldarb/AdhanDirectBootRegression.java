package com.tito.rafeeq_aldarb;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.UserManager;
import com.tito.rafeeq_aldarb.adhan.AdhanScheduler;
import com.tito.rafeeq_aldarb.adhan.AdhanSpec;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import kotlin.Unit;
import org.json.JSONArray;
import org.json.JSONObject;

/** Migration contract on an explicitly owned, isolated emulator only. */
final class AdhanDirectBootRegression {
    static void cleanup(Instrumentation runner) {
        Bundle result = new Bundle();
        try {
            Context context = runner.getTargetContext();
            File marker = new File(context.getFilesDir(), "a12-owned-device");
            if (!marker.isFile()) throw new AssertionError("Refusing cleanup on an unowned device");
            AdhanScheduler.INSTANCE.cancelAll(context);
            context.getSharedPreferences("FlutterSharedPreferences", 0).edit()
                .remove("flutter.a12_private_sentinel").commit();
            File selected = new File(context.getFilesDir(), "a12-selected.mp3");
            if (selected.exists() && !selected.delete()) throw new AssertionError("Cannot remove owned recording");
            context.createDeviceProtectedStorageContext().getSharedPreferences("rafeeq_a12_probe", 0)
                .edit().clear().commit();
            if (!marker.delete()) throw new AssertionError("Cannot remove owned marker");
            result.putString("stream", "PASS: owned alarm fixtures and private sentinel removed");
            runner.finish(Activity.RESULT_OK, result);
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure);
            runner.finish(Activity.RESULT_CANCELED, result);
        }
    }

    static void run(Instrumentation runner) {
        Bundle result = new Bundle();
        Context context = runner.getTargetContext();
        int code = Activity.RESULT_CANCELED;
        try {
            if (!new File(context.getFilesDir(), "a12-owned-device").isFile()) {
                throw new AssertionError("Refusing to seed an unowned device");
            }
            UserManager users = (UserManager) context.getSystemService(Context.USER_SERVICE);
            if (!users.isUserUnlocked()) throw new AssertionError("Migration requires first unlock");
            Context device = context.createDeviceProtectedStorageContext();
            // Each owned run starts at the real legacy-upgrade boundary.
            device.getSharedPreferences("rafeeq_adhan_alarms", 0).edit().clear().commit();
            SharedPreferences legacy = context.getSharedPreferences("rafeeq_adhan_alarms", 0);
            JSONArray rows = new JSONArray();
            for (String prayer : Arrays.asList("fajr", "dhuhr", "asr", "maghrib", "isha")) {
                rows.put(new AdhanSpec(prayer, prayer, "audio", "raw", "azan1",
                    "assets/audio/adhan/azan1.mp3", 0, 0, true, false).toJson());
            }
            JSONObject inputs = new JSONObject();
            inputs.put("lat", 25.2048);
            inputs.put("lon", 55.2708);
            inputs.put("method", 4);
            inputs.put("madhab", "shafi");
            inputs.put("highLatitude", "twilight_angle");
            inputs.put("offsets", new JSONObject());
            legacy.edit().clear().putString("daily_entries_v1", rows.toString())
                .putString("calculation_v1", inputs.toString()).commit();
            String legacyBefore = legacy.getString("daily_entries_v1", null);
            SharedPreferences privatePrefs = context.getSharedPreferences("FlutterSharedPreferences", 0);
            privatePrefs.edit().putString("flutter.a12_private_sentinel", "keep-in-credential-storage").commit();

            Map<String, String> strings = new HashMap<>();
            strings.put(NativeStrings.ADHAN_STOP, "Stop");
            strings.put(NativeStrings.ADHAN_MUTE, "Mute");
            strings.put(NativeStrings.DL_TITLE, "Keep download strings in credential storage");
            NativeStrings.INSTANCE.sync(context, strings);
            StringBuilder failures = new StringBuilder();
            int[] counts = {0, 0};
            check(failures, counts, "legacy schedule remains readable", () ->
                AdhanScheduler.INSTANCE.load(context).size() == 5);
            check(failures, counts, "device-protected schedule contains all five prayers", () ->
                AdhanScheduler.INSTANCE.load(device).size() == 5);
            check(failures, counts, "calculation snapshot migrated", () ->
                device.getSharedPreferences("rafeeq_adhan_alarms", 0)
                    .getString("calculation_v1", "").equals(inputs.toString()));
            check(failures, counts, "credential schedule preserved for rollback", () ->
                legacyBefore.equals(legacy.getString("daily_entries_v1", null)));
            check(failures, counts, "private preference remains credential-only", () ->
                "keep-in-credential-storage".equals(privatePrefs.getString("flutter.a12_private_sentinel", null))
                && !device.getSharedPreferences("FlutterSharedPreferences", 0)
                    .contains("flutter.a12_private_sentinel"));
            check(failures, counts, "chosen adhan language available before unlock", () ->
                "Stop".equals(NativeStrings.INSTANCE.get(device, NativeStrings.ADHAN_STOP)));
            check(failures, counts, "locked boot is registered", () ->
                !context.getPackageManager().queryBroadcastReceivers(
                    new Intent(Intent.ACTION_LOCKED_BOOT_COMPLETED).setPackage(context.getPackageName()),
                    PackageManager.MATCH_DIRECT_BOOT_AWARE).isEmpty());
            check(failures, counts, "adhan service is direct-boot aware", () ->
                context.getPackageManager().getServiceInfo(new android.content.ComponentName(
                    context, "com.tito.rafeeq_aldarb.adhan.AdhanService"),
                    PackageManager.MATCH_DIRECT_BOOT_AWARE | PackageManager.MATCH_DIRECT_BOOT_UNAWARE)
                    .directBootAware);
            CountDownLatch armed = new CountDownLatch(1);
            AtomicBoolean success = new AtomicBoolean();
            AdhanScheduler.INSTANCE.rearmPersisted(context, value -> {
                success.set(value);
                armed.countDown();
                return Unit.INSTANCE;
            });
            if (!armed.await(12, TimeUnit.SECONDS) || !success.get()) {
                throw new AssertionError("Cannot arm actual offline prayer times for reboot control");
            }
            check(failures, counts, "default application storage stays credential-protected", () ->
                !device.getApplicationContext().isDeviceProtectedStorage());
            for (String locale : Arrays.asList("ar", "en", "fr", "es", "pt", "ru", "ur")) {
                Map<String, String> translated = translations(context, locale);
                NativeStrings.INSTANCE.sync(context, translated);
                check(failures, counts, "all eleven direct-boot labels match " + locale, () -> {
                    for (Map.Entry<String, String> entry : translated.entrySet()) {
                        if (!entry.getValue().equals(NativeStrings.INSTANCE.get(device, entry.getKey()))) return false;
                    }
                    return true;
                });
            }
            check(failures, counts, "download strings are not copied to device storage", () -> {
                JSONObject stored = new JSONObject(device.getSharedPreferences("rafeeq_native_strings", 0)
                    .getString("strings_v1", "{}"));
                return stored.length() == 11 && !stored.has(NativeStrings.DL_TITLE);
            });
            File selected = new File(context.getFilesDir(), "a12-selected.mp3");
            try (InputStream input = context.getAssets().open("flutter_assets/assets/audio/adhan/azan1.mp3");
                    FileOutputStream output = new FileOutputStream(selected)) {
                byte[] buffer = new byte[8192];
                int size;
                while ((size = input.read(buffer)) != -1) output.write(buffer, 0, size);
            }
            AdhanSpec original = AdhanScheduler.INSTANCE.load(context).get(0);
            AdhanSpec custom = new AdhanSpec(original.getPrayerKey(), "Fajr", "full", "file",
                selected.getPath(), null, original.getHour(), original.getMinute(), true, true);
            Map<String, Object> snapshot = new HashMap<>();
            snapshot.put("lat", 25.2048); snapshot.put("lon", 55.2708); snapshot.put("method", 4);
            snapshot.put("madhab", "shafi"); snapshot.put("highLatitude", "twilight_angle");
            snapshot.put("offsets", new HashMap<String, Integer>());
            snapshot.put("account_token", "never-migrate-private-input");
            Map<String, Long> next = new HashMap<>();
            java.util.List<AdhanSpec> schedule = AdhanScheduler.INSTANCE.load(context);
            // The existing calculator already armed these real times; inspect the next alarm separately.
            for (AdhanSpec row : schedule) {
                java.util.Calendar time = java.util.Calendar.getInstance();
                time.set(java.util.Calendar.HOUR_OF_DAY, row.getHour());
                time.set(java.util.Calendar.MINUTE, row.getMinute());
                time.set(java.util.Calendar.SECOND, 0); time.set(java.util.Calendar.MILLISECOND, 0);
                if (time.getTimeInMillis() <= System.currentTimeMillis()) time.add(java.util.Calendar.DAY_OF_MONTH, 1);
                next.put(row.getPrayerKey(), time.getTimeInMillis());
            }
            java.util.List<AdhanSpec> selectedSchedule = new java.util.ArrayList<>(schedule);
            selectedSchedule.set(0, custom);
            if (!AdhanScheduler.INSTANCE.scheduleDaily(context, selectedSchedule, snapshot, next))
                throw new AssertionError("Cannot arm exact copied-audio schedule");
            AdhanSpec copied = AdhanScheduler.INSTANCE.load(device).get(0);
            check(failures, counts, "selected custom voice is byte-identical in device storage", () ->
                copied.getSoundValue().startsWith(device.getFilesDir().getCanonicalPath() + "/adhan_audio/")
                && Arrays.equals(hash(selected), hash(new File(copied.getSoundValue()))));
            check(failures, counts, "original selected recording remains available for rollback", () ->
                selected.isFile() && !selected.getPath().equals(copied.getSoundValue()));
            check(failures, counts, "calculation snapshot excludes unrelated private fields", () ->
                !new JSONObject(device.getSharedPreferences("rafeeq_adhan_alarms", 0)
                    .getString("calculation_v1", "{}")).has("account_token"));
            NativeStrings.INSTANCE.sync(context, translations(context, "en"));
            device.getSharedPreferences("rafeeq_a12_probe", 0).edit().putBoolean("owned", true).commit();
            result.putString("stream", "PASS=" + counts[0] + " FAIL=" + counts[1] + failures);
            if (counts[1] == 0) code = Activity.RESULT_OK;
        } catch (Throwable failure) {
            result.putString("stream", "SETUP FAILURE: " + failure);
        }
        runner.finish(code, result);
    }

    private interface Check { boolean run() throws Exception; }
    private static byte[] hash(File file) throws Exception {
        java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
        try (InputStream input = new java.io.FileInputStream(file)) {
            byte[] bytes = new byte[8192]; int size;
            while ((size = input.read(bytes)) != -1) digest.update(bytes, 0, size);
        }
        return digest.digest();
    }
    static Map<String, String> translations(Context context, String locale) throws Exception {
        JSONObject json;
        try (InputStream stream = context.getAssets().open("flutter_assets/assets/translations/" + locale + ".json")) {
            java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[8192]; int size;
            while ((size = stream.read(buffer)) != -1) bytes.write(buffer, 0, size);
            json = new JSONObject(bytes.toString("UTF-8"));
        }
        JSONObject prayer = json.getJSONObject("prayer"), notif = json.getJSONObject("notif");
        Map<String, String> result = new HashMap<>();
        result.put(NativeStrings.ADHAN_CHANNEL, prayer.getString("adhan"));
        result.put(NativeStrings.ADHAN_CHANNEL_DESC, notif.getString("adhan_channel_desc"));
        result.put(NativeStrings.ADHAN_CHANNEL_VIBRATE, prayer.getString("adhan") + " — " + prayer.getString("mode_vibrate"));
        result.put(NativeStrings.ADHAN_CHANNEL_VIBRATE_DESC, notif.getString("adhan_channel_vibrate_desc"));
        result.put(NativeStrings.ADHAN_CHANNEL_SILENT, prayer.getString("adhan") + " — " + prayer.getString("mode_silent"));
        result.put(NativeStrings.ADHAN_CHANNEL_SILENT_DESC, notif.getString("adhan_channel_silent_desc"));
        result.put(NativeStrings.ADHAN_TITLE, prayer.getString("azan_of").replace("{}", "%s"));
        result.put(NativeStrings.ADHAN_BODY, notif.getString("adhan_body"));
        result.put(NativeStrings.ADHAN_BODY_MUTED, notif.getString("adhan_body_muted"));
        result.put(NativeStrings.ADHAN_STOP, prayer.getString("stop"));
        result.put(NativeStrings.ADHAN_MUTE, prayer.getString("mute"));
        return result;
    }
    private static void check(StringBuilder failures, int[] counts, String name, Check check) {
        try {
            if (!check.run()) throw new AssertionError(name);
            counts[0]++;
        } catch (Throwable failure) {
            counts[1]++;
            failures.append("\nFAIL: ").append(name).append(" / ").append(failure);
        }
    }
}
