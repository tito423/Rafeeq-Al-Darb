package com.tito.rafeeq_aldarb

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import java.util.concurrent.TimeUnit

/**
 * Keeps the prayer card's month of events topped up with the app closed:
 * once a day, and once soon whenever [PrayerCard.post] finds it running low.
 * Separate from the adhan job, which is cancelled when no adhan is on; the
 * card may be on without any adhan.
 */
class PrayerCardJob : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        PrayerCard.refreshInBackground(this) { success ->
            jobFinished(params, !success)
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    companion object {
        private const val JOB_ID = 20261112
        private const val SOON_JOB_ID = 20261113

        private fun scheduler(context: Context) =
            context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler

        private fun component(context: Context) =
            ComponentName(context, PrayerCardJob::class.java)

        fun ensureScheduled(context: Context) {
            val s = scheduler(context)
            if (s.getPendingJob(JOB_ID) != null) return
            s.schedule(JobInfo.Builder(JOB_ID, component(context))
                .setPeriodic(TimeUnit.DAYS.toMillis(1), TimeUnit.HOURS.toMillis(6))
                .setPersisted(true)
                .build())
        }

        /** One refresh within minutes, retried with backoff until it works. */
        fun runSoon(context: Context) {
            val s = scheduler(context)
            if (s.getPendingJob(SOON_JOB_ID) != null) return
            s.schedule(JobInfo.Builder(SOON_JOB_ID, component(context))
                .setMinimumLatency(TimeUnit.SECONDS.toMillis(5))
                .setOverrideDeadline(TimeUnit.MINUTES.toMillis(30))
                .setBackoffCriteria(TimeUnit.MINUTES.toMillis(5), JobInfo.BACKOFF_POLICY_EXPONENTIAL)
                .setPersisted(true)
                .build())
        }

        fun cancel(context: Context) {
            scheduler(context).cancel(JOB_ID)
            scheduler(context).cancel(SOON_JOB_ID)
        }
    }
}
