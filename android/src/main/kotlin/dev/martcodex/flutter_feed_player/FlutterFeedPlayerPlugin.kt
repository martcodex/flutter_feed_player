package dev.martcodex.flutter_feed_player

import android.app.Activity
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlutterFeedPlayerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private var eligible = false
    private var aspectW = 9
    private var aspectH = 16

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
        instance = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        if (instance === this) instance = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        applyAutoEnter()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        applyAutoEnter()
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setEligible" -> {
                eligible = call.argument<Boolean>("eligible") == true
                aspectW = (call.argument<Int>("width") ?: 9).coerceAtLeast(1)
                aspectH = (call.argument<Int>("height") ?: 16).coerceAtLeast(1)
                applyAutoEnter()
                result.success(null)
            }
            "enter" -> result.success(enterIfEligible())
            "isActive" -> result.success(inPip())
            "keepPlaying" -> result.success(inPip())
            else -> result.notImplemented()
        }
    }

    private fun applyAutoEnter() {
        val act = activity ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val builder = android.app.PictureInPictureParams.Builder()
            .setAspectRatio(aspectRatio())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(eligible)
        }
        try {
            act.setPictureInPictureParams(builder.build())
        } catch (_: IllegalArgumentException) {
        } catch (_: IllegalStateException) {
        }
    }

    fun enterIfEligible(): Boolean {
        val act = activity ?: return false
        if (!eligible) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (inPip()) return true
        // API 31+ enters from setAutoEnterEnabled. Calling enter again here
        // races with the system and can throw.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return inPip()
        return try {
            val entered = act.enterPictureInPictureMode(
                android.app.PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio())
                    .build(),
            )
            if (entered) notifyPip(true)
            entered
        } catch (_: IllegalArgumentException) {
            false
        } catch (_: IllegalStateException) {
            false
        }
    }

    private fun inPip(): Boolean {
        val act = activity ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return act.isInPictureInPictureMode
    }

    fun notifyPip(active: Boolean) {
        channel?.invokeMethod("onPipModeChanged", active)
    }

    private fun aspectRatio(): Rational {
        var ratio = if (aspectH <= 0) 9f / 16f else aspectW.toFloat() / aspectH.toFloat()
        if (!ratio.isFinite() || ratio <= 0f) ratio = 9f / 16f
        // Stay inside Android's 1/2.39 … 2.39 window with margin.
        ratio = ratio.coerceIn(0.45f, 2.35f)
        val w = (ratio * 1000f).toInt().coerceAtLeast(1)
        val h = 1000
        val g = gcd(w, h)
        return Rational(w / g, h / g)
    }

    private fun gcd(a: Int, b: Int): Int {
        var x = a
        var y = b
        while (y != 0) {
            val t = x % y
            x = y
            y = t
        }
        return if (x == 0) 1 else x
    }

    companion object {
        const val CHANNEL = "flutter_feed_player/pip"

        var instance: FlutterFeedPlayerPlugin? = null

        fun onUserLeaveHint() {
            instance?.enterIfEligible()
        }

        fun onPipModeChanged(active: Boolean) {
            instance?.notifyPip(active)
        }
    }
}
