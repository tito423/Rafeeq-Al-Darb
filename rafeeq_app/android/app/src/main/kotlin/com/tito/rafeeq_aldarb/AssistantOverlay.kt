package com.tito.rafeeq_aldarb

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * «رفيق» over any other app or the home screen (owner, 2026-09-29: «رفيق مش
 * بيشتغل فوق أي أب … لما أنده عليه يطلع … واللي أطلبه منه يفتحه في تطبيقنا مش
 * إنه يفتح بشاشة كاملة»).
 *
 * Until now the wake word was heard in the background but nothing could show:
 * Android refuses to start an activity from a background app, so «toFront»
 * silently failed. A window drawn with TYPE_APPLICATION_OVERLAY needs the
 * «Display over other apps» permission and is allowed to appear at any time;
 * the same permission is also what lets the app then bring its own screen
 * forward for the command that was asked.
 *
 * This is a small card, not a screen: a microphone and one line of text
 * («أسمعك…», what was understood, what is being opened), at the top of the
 * screen, taking no touches, gone after a few seconds.
 */
object AssistantOverlay {
    private val main = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var label: TextView? = null
    private val hider = Runnable { hide() }

    fun canDraw(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    /** The system screen where the reader grants «Display over other apps». */
    fun settingsIntent(context: Context): android.content.Intent =
        android.content.Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:" + context.packageName),
        ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun dp(context: Context, v: Int) = (v * context.resources.displayMetrics.density).toInt()

    fun show(context: Context, text: String, seconds: Int, rtl: Boolean) {
        val app = context.applicationContext
        if (!canDraw(app)) return
        main.post {
            main.removeCallbacks(hider)
            val existing = label
            if (existing != null && view != null) {
                existing.text = text
            } else {
                val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val row = LinearLayout(app).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    layoutDirection = if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
                    setPadding(dp(app, 18), dp(app, 12), dp(app, 20), dp(app, 12))
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#F2071626"))
                        cornerRadius = dp(app, 30).toFloat()
                        setStroke(dp(app, 1), Color.parseColor("#D4AF37"))
                    }
                    elevation = dp(app, 8).toFloat()
                }
                val mic = ImageView(app).apply {
                    setImageResource(android.R.drawable.ic_btn_speak_now)
                    setColorFilter(Color.parseColor("#D4AF37"))
                }
                row.addView(mic, LinearLayout.LayoutParams(dp(app, 26), dp(app, 26)))
                val tv = TextView(app).apply {
                    this.text = text
                    setTextColor(Color.WHITE)
                    textSize = 17f
                    typeface = Typeface.DEFAULT_BOLD
                    maxLines = 3
                    textDirection = if (rtl) View.TEXT_DIRECTION_RTL else View.TEXT_DIRECTION_LTR
                }
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
                lp.marginStart = dp(app, 12)
                row.addView(tv, lp)
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT,
                ).apply {
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    y = dp(app, 56)
                }
                try {
                    wm.addView(row, params)
                    view = row
                    label = tv
                } catch (e: Exception) {
                    view = null
                    label = null
                }
            }
            main.postDelayed(hider, seconds * 1000L)
        }
    }

    fun hide() {
        main.post {
            main.removeCallbacks(hider)
            val v = view ?: return@post
            try {
                val wm = v.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.removeView(v)
            } catch (_: Exception) {
            }
            view = null
            label = null
        }
    }
}
