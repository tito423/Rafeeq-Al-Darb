package com.tito.rafeeq_aldarb;

import android.app.Activity;
import android.app.Application;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;

import java.util.concurrent.atomic.AtomicReference;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.android.FlutterActivity;

/** Retained audio engine: navigation ownership must survive a new host. */
final class BackNavigationRegression {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static FlutterEngine attachedEngine(MainActivity activity) {
        try {
            java.lang.reflect.Method method = FlutterActivity.class.getDeclaredMethod("getFlutterEngine");
            method.setAccessible(true);
            return (FlutterEngine) method.invoke(activity);
        } catch (ReflectiveOperationException failure) {
            throw new AssertionError(failure);
        }
    }

    static void run(Instrumentation instrumentation) {
        Bundle result = new Bundle();
        int code = Activity.RESULT_CANCELED;
        AtomicReference<MainActivity> resumed = new AtomicReference<>();
        AtomicReference<Boolean> startedBack = new AtomicReference<>();
        Application application = (Application) instrumentation.getTargetContext().getApplicationContext();
        Application.ActivityLifecycleCallbacks callbacks = new Application.ActivityLifecycleCallbacks() {
            public void onActivityCreated(Activity a, Bundle b) { }
            public void onActivityStarted(Activity a) {
                if (a instanceof MainActivity) startedBack.set(((MainActivity) a).getBackCallbackState());
            }
            public void onActivityResumed(Activity a) {
                if (a instanceof MainActivity) resumed.set((MainActivity) a);
            }
            public void onActivityPaused(Activity a) { }
            public void onActivityStopped(Activity a) { }
            public void onActivitySaveInstanceState(Activity a, Bundle b) { }
            public void onActivityDestroyed(Activity a) { }
        };
        application.registerActivityLifecycleCallbacks(callbacks);
        try {
            Intent launcher = application.getPackageManager().getLaunchIntentForPackage(application.getPackageName());
            check(launcher != null, "Launcher missing");
            application.startActivity(launcher);
            for (int i = 0; i < 200 && resumed.get() == null; i++) SystemClock.sleep(100);
            check(resumed.get() != null, "Activity did not resume");
            SystemClock.sleep(8000);
            // Drive the real Dart Navigator through Flutter's navigation
            // channel. A '/' push opens the existing Splash/Home flow above
            // the first route; a pop returns to that first route. Do not
            // invent a decision that conflicts with the actual Dart route.
            for (boolean handlesBack : new boolean[] {true, false, true}) {
                MainActivity old = resumed.get();
                FlutterEngine engine = attachedEngine(old);
                instrumentation.runOnMainSync(() -> {
                    if (handlesBack) engine.getNavigationChannel().pushRoute("/");
                    else engine.getNavigationChannel().popRoute();
                });
                boolean[] routeDecision = new boolean[1];
                if (Build.VERSION.SDK_INT >= 33) {
                    for (int i = 0; i < 200; i++) {
                        instrumentation.runOnMainSync(() -> routeDecision[0] = old.getBackCallbackState());
                        if (routeDecision[0] == handlesBack) break;
                        SystemClock.sleep(100);
                    }
                    check(routeDecision[0] == handlesBack, "Dart route did not send expected Back decision");
                } else {
                    SystemClock.sleep(5000);
                }
                startedBack.set(null);
                instrumentation.runOnMainSync(() -> {
                    old.recreate();
                });
                for (int i = 0; i < 100 && resumed.get() == old; i++) SystemClock.sleep(100);
                MainActivity next = resumed.get();
                check(next != old, "Activity was not recreated");
                check(startedBack.get() != null, "Recreated activity did not start");
                boolean[] observed = new boolean[2];
                instrumentation.runOnMainSync(() -> {
                    observed[0] = attachedEngine(next) == engine;
                    // Observe the host after restoration, before a later
                    // navigation notification could hide a lost decision.
                    observed[1] = startedBack.get();
                });
                check(observed[0], "The audio engine must be retained");
                if (Build.VERSION.SDK_INT >= 33) {
                    check(observed[1] == handlesBack,
                        "Recreated host lost framework Back decision: " + handlesBack);
                }
            }
            MainActivity last = resumed.get();
            instrumentation.runOnMainSync(() -> attachedEngine(last).getNavigationChannel().popRoute());
            result.putString("stream", "PASS: retained engine and true/false/true Back ownership across recreation\n");
            code = Activity.RESULT_OK;
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure + "\n");
        } finally {
            application.unregisterActivityLifecycleCallbacks(callbacks);
            instrumentation.finish(code, result);
        }
    }
}
