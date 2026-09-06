package com.tito.rafeeq_aldarb.adhan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * `AlarmManager` drops every alarm on reboot (and on some OEM skins after an
 * app update or a timezone change), so the Adhan has to re-arm itself from
 * the schedule [AdhanScheduler] persisted — otherwise a phone that is
 * restarted at night calls no adhan until the user happens to open the app.
 */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.intent.action.QUICKBOOT_POWERON",
            -> AdhanScheduler.rearmPersisted(context)
        }
    }
}
