package com.tito.rafeeq_aldarb.adhan

import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.json.JSONObject
import java.net.URLEncoder

/**
 * The Adhan alert screen — the "ringing phone" surface.
 *
 * It is a **separate Activity in its own task**, not `MainActivity`, and
 * that is the whole point of this rewrite:
 *
 *  • `showWhenLocked` + `turnScreenOn` (set both in the manifest *and* here,
 *    because some OEM skins honour only one of the two paths) mean it draws
 *    over the lock screen and wakes the display, exactly like an alarm clock
 *    or an incoming call — no unlock, no biometric first.
 *  • Its own `taskAffinity` + `excludeFromRecents` mean firing it never
 *    disturbs whatever the user was doing in the app, and dismissing it
 *    returns them to the lock screen / the app they were in, instead of
 *    dumping them somewhere inside Rafeeq.
 *  • It runs a **dedicated Dart entrypoint** (`adhanMain`) rather than the
 *    whole app, so the alert is on screen fast and cannot be affected by the
 *    main app's own navigation state.
 *
 * It is launched two ways at once, on purpose: directly by [AdhanService]
 * (`startActivity`, which is allowed because an exact-alarm broadcast grants
 * the app a temporary background-activity-start exemption) *and* as the
 * `fullScreenIntent` of the service's notification. Whichever the device
 * honours, the screen appears; `singleTask` collapses the two into one.
 */
class AdhanActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName(): String = ENTRYPOINT

    override fun getInitialRoute(): String =
        intent?.getStringExtra(EXTRA_ROUTE) ?: "/azan"

    override fun onCreate(savedInstanceState: Bundle?) {
        applyLockScreenFlags()
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun onNewIntent(intent: Intent) {
        // A second delivery (the direct start and the full-screen intent can
        // both land). The screen is already up and the service already owns
        // the audio, so there is nothing to re-run — just keep the newer
        // Intent so `getInitialRoute` stays consistent if we're recreated.
        setIntent(intent)
        applyLockScreenFlags()
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AdhanChannels.register(this, flutterEngine, this, isAlertHost = true)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun applyLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            // Only on a *non-secure* keyguard: this slides the lock screen out
            // of the way so the alert is immediately interactive. On a secure
            // keyguard it would demand the user's PIN before they could even
            // silence the adhan, so it is deliberately not requested there —
            // `setShowWhenLocked` already draws the alert above it.
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            if (km != null && !km.isKeyguardSecure) {
                km.requestDismissKeyguard(this, null)
            }
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        // The adhan is ~2-4 minutes of a screen the user is meant to watch;
        // scoped to this Activity, so nothing else in the app holds it.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    companion object {
        /** Must match the `@pragma('vm:entry-point')` function in `lib/adhan_entry.dart`. */
        const val ENTRYPOINT = "adhanMain"
        private const val EXTRA_ROUTE = "rafeeq.adhan.route"

        /** Live instance, so [AdhanService] can close the screen on "إيقاف". */
        @Volatile
        private var instance: AdhanActivity? = null

        fun finishIfShowing() {
            instance?.let { activity ->
                activity.runOnUiThread {
                    activity.finishAndRemoveTask()
                }
            }
        }

        fun intentFor(context: Context, spec: AdhanSpec): Intent =
            Intent(context, AdhanActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_USER_ACTION,
                )
                spec.writeTo(this)
                putExtra(EXTRA_ROUTE, routeFor(spec))
            }

        fun pendingIntent(context: Context, spec: AdhanSpec): PendingIntent =
            PendingIntent.getActivity(
                context,
                spec.requestCode,
                intentFor(context, spec),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        /**
         * `/azan?d=<url-encoded JSON>` — Flutter reads this back out of
         * `PlatformDispatcher.instance.defaultRouteName`. Encoding the whole
         * spec as one query value keeps the route a plain, safe ASCII string
         * even though the label is Arabic and paths contain slashes.
         */
        private fun routeFor(spec: AdhanSpec): String {
            val json: JSONObject = spec.toJson()
            val encoded = URLEncoder.encode(json.toString(), "UTF-8")
            return "/azan?d=$encoded"
        }
    }
}
