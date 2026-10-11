package com.tito.rafeeq_aldarb;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.SystemClock;

import com.tito.rafeeq_aldarb.adhan.AdhanPlayer;
import com.tito.rafeeq_aldarb.adhan.AdhanService;
import com.tito.rafeeq_aldarb.adhan.AdhanSpec;

/** Actual native MediaPlayer ownership; no alarms or settings are changed. */
final class AdhanPreviewRegression {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    static void run(Instrumentation instrumentation) {
        Bundle result = new Bundle();
        int code = Activity.RESULT_CANCELED;
        Context context = instrumentation.getTargetContext();
        AdhanPlayer player = AdhanPlayer.INSTANCE;
        AdhanSpec sound = new AdhanSpec("dhuhr", "Audit preview", "audio", "raw",
            "azan1", "assets/audio/adhan/azan1.mp3", 0, 0, false, false);
        boolean[] ownsPlayback = {false};
        try {
            Intent launcher = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (launcher == null) throw new AssertionError("Missing launcher");
            context.startActivity(launcher);
            SystemClock.sleep(5000);
            instrumentation.runOnMainSync(() -> {
                check(AdhanService.Companion.getCurrent() == null && !player.isPlaying(),
                    "Existing playback must be preserved; do not run this suite while an adhan is firing");
                ownsPlayback[0] = true;
                check(player.startPreview(context, sound, "audit_A27/one"), "Owned preview must start");
                check(player.isPlaying(), "Real MediaPlayer must be playing");
                check(player.stopPreview("audit_A27/one"), "Matching owner must stop");
                check(!player.isPlaying(), "Matching stop must release playback");
                check(player.startPreview(context, sound, "audit_A27/old"), "Old preview must start");
                check(player.startPreview(context, sound, "audit_A27/new"), "New preview must replace old");
                check(!player.stopPreview("audit_A27/old"), "Stale owner must be rejected");
                check(player.isPlaying() && "audit_A27/new".equals(player.getPreviewOwner()),
                    "Stale cleanup must preserve newer playback");
                check(player.stopPreview("audit_A27/new"), "New owner must stop its own playback");
                check(player.startPreview(context, sound, "audit_A27/old"), "Preview must start again");
                // AdhanService uses this same non-preview start path. No
                // foreground firing, alarm or notification is created here.
                check(player.start(context, sound, null), "Non-preview start must succeed");
                check(!player.stopPreview("audit_A27/old"), "Preview cleanup must not stop real-start playback");
                check(player.isPlaying() && player.getPreviewOwner() == null,
                    "Non-preview playback must keep playing without a preview owner");
                check(!player.startPreview(context, sound, "audit_A27/intruder"),
                    "A new preview must not interrupt non-preview playback");
                check(player.isPlaying(), "Rejected preview must preserve non-preview playback");
            });
            SystemClock.sleep(250);
            instrumentation.runOnMainSync(() -> check(player.getPositionMs() > 0,
                "Native decoder position must actually advance"));
            result.putString("stream", "PASS: owned stop, stale owner, real-start protection, decoder progress\n");
            code = Activity.RESULT_OK;
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure + "\n");
        } finally {
            if (ownsPlayback[0]) instrumentation.runOnMainSync(() -> {
                if (AdhanService.Companion.getCurrent() == null) player.stop();
            });
            instrumentation.finish(code, result);
        }
    }
}
