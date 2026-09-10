package com.tito.rafeeq_aldarb

import android.app.Application
import android.util.Log
import androidx.work.Configuration

/**
 * The app's Application class, and it exists for exactly one reason:
 * **WorkManager must not initialise itself on every process start.**
 *
 * THE ANR THIS ADDRESSES, measured on emulator-5554 rather than reasoned
 * about. Twice in one session:
 *
 *     ANR in com.tito.rafeeq_aldarb
 *     Reason: Process ... failed to complete startup
 *
 * That is not the "a touch went unanswered" ANR — it is Android starting the
 * process, waiting **ten seconds** for it to finish binding, and killing it
 * when it does not. In the same log, the runtime reported 65 slow class
 * verifications totalling **9,724 ms**, i.e. essentially the whole budget,
 * before the app had done anything of its own. Grouped by library:
 *
 *     androidx.work        45
 *     kotlinx.coroutines   29
 *     androidx.room        13
 *     com.google.gson       8
 *     androidx.sqlite       5
 *
 * WorkManager dominates, and it is dragging Room, SQLite and coroutines in
 * with it. `androidx.startup`'s `InitializationProvider` runs
 * `WorkManagerInitializer` in a ContentProvider **before**
 * `Application.onCreate` returns, on every process start — including the ones
 * that have nothing to do with downloading. Both ANRs here were on a process
 * started for a broadcast:
 *
 *     Start proc ... for broadcast
 *     {...flutterlocalnotifications.ScheduledNotificationBootReceiver}
 *
 * A scheduled notification woke the process and paid for WorkManager's entire
 * database stack to be verified, for nothing.
 *
 * On-demand initialisation is Google's own documented alternative: remove the
 * initializer from the manifest, implement [Configuration.Provider], and
 * WorkManager builds itself the first time something actually calls
 * `WorkManager.getInstance()`. For this app that is when a download starts —
 * `background_downloader` — which is precisely when the cost is worth paying.
 *
 * HONESTY ABOUT SCOPE. The owner has never seen this ANR. This emulator is
 * x86_64 with no AOT profile for these libraries, so it verifies every method
 * at runtime; a real ARM phone with a cloud profile verifies a fraction of
 * them. The startup work is real on both, but only here does it reach the
 * limit. The change is worth making anyway — a notification waking the app
 * should not build a WorkManager database — but it is not a fix for something
 * he reported.
 */
class RafeeqApplication : Application(), Configuration.Provider {

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            // Warnings only. WorkManager's INFO level logs every enqueue and
            // every state change, and this app enqueues one task per ayah —
            // 286 for a single surah.
            .setMinimumLoggingLevel(Log.WARN)
            .build()
}
