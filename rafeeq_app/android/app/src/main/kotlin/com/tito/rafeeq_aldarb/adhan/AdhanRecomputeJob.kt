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
        AdhanScheduler.rearmPersisted(this) { success -> jobFinished(params, !success) }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    companion object {
        private const val JOB_ID = 20261011

        fun ensureScheduled(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (scheduler.getPendingJob(JOB_ID) != null) return
            scheduler.schedule(JobInfo.Builder(JOB_ID, ComponentName(context, AdhanRecomputeJob::class.java))
                .setPeriodic(TimeUnit.DAYS.toMillis(1), TimeUnit.HOURS.toMillis(1))
                .setPersisted(true)
                .build())
        }

        fun cancel(context: Context) {
            (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB_ID)
        }
    }
}
