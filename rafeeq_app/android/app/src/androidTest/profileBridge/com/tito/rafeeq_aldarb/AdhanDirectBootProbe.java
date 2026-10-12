package com.tito.rafeeq_aldarb;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.UserManager;
import android.util.Log;
import com.tito.rafeeq_aldarb.adhan.AdhanCalculation;
import com.tito.rafeeq_aldarb.adhan.AdhanScheduler;
import com.tito.rafeeq_aldarb.adhan.AdhanService;
import com.tito.rafeeq_aldarb.adhan.AdhanPlayer;
import com.tito.rafeeq_aldarb.adhan.AdhanSpec;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import kotlin.Unit;
import org.json.JSONObject;

/** Shell-only QA transport, included ONLY in explicitly requested profile fixtures. */
public final class AdhanDirectBootProbe extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        Context device = context.createDeviceProtectedStorageContext();
        if (!device.getSharedPreferences("rafeeq_a12_probe", 0).getBoolean("owned", false)) return;
        String mode = intent.getStringExtra("mode");
        try {
            UserManager users = (UserManager) context.getSystemService(Context.USER_SERVICE);
            List<AdhanSpec> specs = AdhanScheduler.INSTANCE.load(context);
            if ("fire".equals(mode)) {
                if (specs.size() != 5) throw new AssertionError("Missing actual five-prayer schedule");
                AdhanSpec selected = specs.get(0);
                AdhanSpec full = new AdhanSpec(selected.getPrayerKey(), selected.getPrayerLabel(), "full",
                    selected.getSoundType(), selected.getSoundValue(), selected.getAssetPath(),
                    selected.getHour(), selected.getMinute(), false, true);
                if (!AdhanScheduler.INSTANCE.scheduleOneShot(context, full, 2000))
                    throw new AssertionError("Exact one-shot alarm refused");
            } else if ("compute".equals(mode)) {
                JSONObject snapshot = new JSONObject(device.getSharedPreferences("rafeeq_adhan_alarms", 0)
                    .getString("calculation_v1", "{}"));
                PendingResult pending = goAsync();
                AdhanCalculation.INSTANCE.compute(context, map(snapshot), System.currentTimeMillis(), targets -> {
                    Log.i("AdhanA12Probe", "computed=" + (targets != null && targets.size() == 5)
                        + " unlocked=" + users.isUserUnlocked());
                    pending.finish();
                    return Unit.INSTANCE;
                });
                return;
            } else if ("stop".equals(mode)) {
                AdhanService.Companion.stop(context);
            } else if ("mute".equals(mode)) {
                AdhanService.Companion.mute(context);
            }
            boolean credentialBlocked = false;
            if (!users.isUserUnlocked()) {
                try { context.getSharedPreferences("FlutterSharedPreferences", 0).getAll(); }
                catch (IllegalStateException expected) { credentialBlocked = true; }
            }
            Log.i("AdhanA12Probe", new JSONObject()
                .put("unlocked", users.isUserUnlocked()).put("credentialBlocked", credentialBlocked)
                .put("rows", specs.size()).put("playing", AdhanPlayer.INSTANCE.isPlaying())
                .put("positionMs", AdhanPlayer.INSTANCE.getPositionMs())
                .put("muted", AdhanPlayer.INSTANCE.isMuted())
                .put("firing", AdhanService.Companion.getCurrent() != null).toString());
        } catch (Throwable failure) {
            Log.e("AdhanA12Probe", "FAIL: " + failure);
        }
    }

    private static Map<String, Object> map(JSONObject json) throws Exception {
        Map<String, Object> result = new HashMap<>();
        for (Iterator<String> keys = json.keys(); keys.hasNext();) {
            String key = keys.next(); Object value = json.get(key);
            result.put(key, value instanceof JSONObject ? map((JSONObject) value) : value);
        }
        return result;
    }
}
