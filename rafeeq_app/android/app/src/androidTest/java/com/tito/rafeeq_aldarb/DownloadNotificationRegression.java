package com.tito.rafeeq_aldarb;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.Instrumentation;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.service.notification.StatusBarNotification;

/** Real platform regression: run on API 24 and a current Android emulator. */
public final class DownloadNotificationRegression extends Instrumentation {
    private String suite;
    @Override
    public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        suite = arguments.getString("suite", "downloads");
        start();
    }

    @Override
    public void onStart() {
        if ("adhan".equals(suite)) {
            AdhanRecomputeRegression.run(this);
            return;
        }
        Bundle result = new Bundle();
        int resultCode = Activity.RESULT_CANCELED;
        Context context = getTargetContext();
        Intent service = new Intent(context, DownloadForegroundService.class);
        try {
            // Exercise both builders without depending on a remote download.
            runOnMainSync(() -> {
                DownloadForegroundService.Companion.build(context, null, null, 1, 2);
            });
            Intent launcher = context.getPackageManager()
                .getLaunchIntentForPackage(context.getPackageName());
            if (launcher == null) throw new AssertionError("Missing launcher");
            context.startActivity(launcher);
            // Let Flutter finish its startup notification cleanup first.
            SystemClock.sleep(5000);
            service.setAction(DownloadForegroundService.ACTION_START);
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service);
            else context.startService(service);
            for (int i = 0; i < 100 && !DownloadForegroundService.Companion.getRunning(); i++) {
                SystemClock.sleep(100);
            }
            if (!DownloadForegroundService.Companion.getRunning()) {
                throw new AssertionError("Foreground service did not start");
            }
            runOnMainSync(() -> DownloadForegroundService.Companion.updateItem(
                context, "compatibility-regression", null, null, 1, 2));
            NotificationManager manager = (NotificationManager)
                context.getSystemService(Context.NOTIFICATION_SERVICE);
            boolean summary = false;
            boolean item = false;
            int itemId = BuildConfig.NOTIFICATION_DOWNLOAD_ITEMS
                + ("compatibility-regression".hashCode() & 0x7fffffff)
                    % BuildConfig.NOTIFICATION_DOWNLOAD_ITEMS_COUNT;
            // Posts are asynchronous; Android 12+ may defer foreground
            // notifications for ten seconds. Keep both assertions intact.
            for (int i = 0; i < 300 && (!summary || !item); i++) {
                summary = false;
                item = false;
                for (StatusBarNotification notification : manager.getActiveNotifications()) {
                    if (notification.getId() == BuildConfig.NOTIFICATION_DOWNLOAD_FOREGROUND) summary = true;
                    if (notification.getId() == itemId) item = true;
                }
                if (!summary || !item) SystemClock.sleep(50);
            }
            if (!summary || !item) throw new AssertionError("Missing summary or progress item: "
                + summary + "/" + item + ", running=" + DownloadForegroundService.Companion.getRunning());
            if ("timeout".equals(suite)) {
                if (Build.VERSION.SDK_INT < 35) throw new AssertionError("Timeout suite requires API 35+");
                Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(home);
                for (int i = 0; i < 200 && DownloadForegroundService.Companion.getRunning(); i++) {
                    SystemClock.sleep(100);
                }
                if (DownloadForegroundService.Companion.getRunning()) {
                    throw new AssertionError("Timed-out foreground service remains running");
                }
                ActivityManager activities = (ActivityManager)
                    context.getSystemService(Context.ACTIVITY_SERVICE);
                for (int i = 0; i < 100; i++) {
                    boolean registered = false;
                    for (ActivityManager.RunningServiceInfo info : activities.getRunningServices(100)) {
                        if (info.service.getClassName().equals(DownloadForegroundService.class.getName())) {
                            registered = true;
                        }
                    }
                    if (!registered) break;
                    if (i == 99) throw new AssertionError("Timed-out service did not stopSelf");
                    SystemClock.sleep(50);
                }
                // Notification cancellation is asynchronous too.
                for (int i = 0; i < 100; i++) {
                    boolean present = false;
                    for (StatusBarNotification notification : manager.getActiveNotifications()) {
                        if (notification.getId() == itemId || notification.getId()
                            == BuildConfig.NOTIFICATION_DOWNLOAD_FOREGROUND) present = true;
                    }
                    if (!present) break;
                    if (i == 99) throw new AssertionError("Timeout left download notifications behind");
                    SystemClock.sleep(50);
                }
                context.startActivity(launcher);
                SystemClock.sleep(2000);
                context.startForegroundService(service);
                for (int i = 0; i < 100 && !DownloadForegroundService.Companion.getRunning(); i++) {
                    SystemClock.sleep(50);
                }
                if (!DownloadForegroundService.Companion.getRunning()) {
                    throw new AssertionError("Foreground return cannot restart download protection");
                }
            }
            result.putString("stream", "PASS: summary, channel, foreground service and item on API "
                + Build.VERSION.SDK_INT + ("timeout".equals(suite) ? ", timeout cleanup and foreground restart" : ""));
            resultCode = Activity.RESULT_OK;
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure);
        } finally {
            runOnMainSync(() -> DownloadForegroundService.Companion.finishItem(
                context, "compatibility-regression"));
            context.stopService(service);
            for (int i = 0; i < 100 && DownloadForegroundService.Companion.getRunning(); i++) {
                SystemClock.sleep(50);
            }
        }
        finish(resultCode, result);
    }
}
