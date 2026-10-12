package com.tito.rafeeq_aldarb.adhan

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.tito.rafeeq_aldarb.NativeStrings

/** The first-unlock alert uses native views and the existing translated snapshot. */
class AdhanLockedActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var body: TextView? = null
    private var ownsService = false
    private val refresh = object : Runnable {
        override fun run() {
            if (ownsService && AdhanService.current == null) {
                finishAndRemoveTask()
                return
            }
            body?.text = NativeStrings.get(this@AdhanLockedActivity,
                if (AdhanPlayer.isMuted) NativeStrings.ADHAN_BODY_MUTED else NativeStrings.ADHAN_BODY)
            handler.postDelayed(this, 250)
        }
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        instance = this
        if (Build.VERSION.SDK_INT >= 33) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { dismiss() }
        }
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        renderAlert()
        handler.post(refresh)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        renderAlert()
    }

    private fun renderAlert() {
        ownsService = AdhanService.current != null
        val spec = AdhanSpec.fromIntent(intent) ?: return finish()
        val padding = (24 * resources.displayMetrics.density).toInt()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(padding, padding, padding, padding)
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.rgb(20, 39, 57), Color.rgb(6, 16, 28)))
        }
        fun label(text: String, size: Float): TextView = TextView(this).apply {
            this.text = text
            textSize = size
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setPadding(0, padding, 0, padding)
        }
        content.addView(label(NativeStrings.get(this, NativeStrings.ADHAN_TITLE)
            .replace("%s", spec.prayerLabel), 28f))
        body = label(NativeStrings.get(this, NativeStrings.ADHAN_BODY), 20f)
        content.addView(body)
        val mute = Button(this).apply {
            text = NativeStrings.get(this@AdhanLockedActivity, NativeStrings.ADHAN_MUTE)
            setOnClickListener {
                AdhanService.mute(this@AdhanLockedActivity)
                body?.text = NativeStrings.get(this@AdhanLockedActivity, NativeStrings.ADHAN_BODY_MUTED)
            }
        }
        content.addView(mute)
        content.addView(Button(this).apply {
            text = NativeStrings.get(this@AdhanLockedActivity, NativeStrings.ADHAN_STOP)
            setOnClickListener {
                dismiss()
            }
        })
        setContentView(content)
    }

    @Deprecated("Legacy Android back callback")
    override fun onBackPressed() {
        dismiss()
    }

    private fun dismiss() {
        AdhanService.stop(this)
        finishAndRemoveTask()
    }

    override fun onDestroy() {
        handler.removeCallbacks(refresh)
        if (instance === this) instance = null
        super.onDestroy()
    }

    companion object {
        @Volatile private var instance: AdhanLockedActivity? = null
        val isShowing: Boolean get() = instance != null
        fun finishIfShowing() { instance?.let { it.runOnUiThread { it.finishAndRemoveTask() } } }
    }
}
