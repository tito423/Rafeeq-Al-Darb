package com.tito.rafeeq_aldarb.adhan

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import java.util.concurrent.TimeUnit

/** Daily safety refresh also runs if an OEM drops an individual prayer alarm. */
class AdhanRecomputeJob : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        AdhanScheduler.rearmPersisted(this, retryOnFailure = false) { success ->
            jobFinished(params, !success)
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    companion object {
        private const val JOB_ID = 20261011
        private const val RETRY_JOB_ID = 20261013

        /**
         * A firing consumes its alarm; if the headless calculation then fails
         * (timeout, engine start, low memory) that prayer has no alarm until
         * the daily job, which may be ~24h away. Retry within minutes instead,
         * with the scheduler's exponential backoff until it succeeds.
         */
        fun scheduleRetry(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (scheduler.getPendingJob(RETRY_JOB_ID) != null) return
            scheduler.schedule(JobInfo.Builder(RETRY_JOB_ID, ComponentName(context, AdhanRecomputeJob::class.java))
                .setMinimumLatency(TimeUnit.MINUTES.toMillis(1))
                .setOverrideDeadline(TimeUnit.MINUTES.toMillis(15))
                .setBackoffCriteria(TimeUnit.MINUTES.toMillis(2), JobInfo.BACKOFF_POLICY_EXPONENTIAL)
                .setPersisted(true)
                .build())
        }

        fun ensureScheduled(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (scheduler.getPendingJob(JOB_ID) != null) return
            scheduler.schedule(JobInfo.Builder(JOB_ID, ComponentName(context, AdhanRecomputeJob::class.java))
                .setPeriodic(TimeUnit.DAYS.toMillis(1), TimeUnit.HOURS.toMillis(1))
                .setPersisted(true)
                .build())
        }

        fun cancel(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            scheduler.cancel(JOB_ID)
            scheduler.cancel(RETRY_JOB_ID)
        }
    }
}
