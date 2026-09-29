package com.poweragent.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CH = "com.poweragent/accessibility"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, CH).setMethodCallHandler { call, result ->
            val svc = PowerAccessibilityService.instance
            try {
                when (call.method) {
                    "ping" -> result.success("pong")
                    "isServiceRunning" -> result.success(svc != null)
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    }
                    "dumpScreen" -> result.success(svc?.dumpScreen() ?: "")
                    "takeScreenshot" -> result.success(svc?.takeScreenshotBase64())
                    "clickByText" -> result.success(svc?.clickByText(call.argument<String>("text") ?: "") ?: false)
                    "clickAt" -> result.success(svc?.clickAt(call.argument<Int>("x") ?: 500, call.argument<Int>("y") ?: 500) ?: false)
                    "doubleTap" -> result.success(svc?.doubleTap(call.argument<Int>("x") ?: 500, call.argument<Int>("y") ?: 500) ?: false)
                    "longPressAt" -> result.success(svc?.longPress(call.argument<Int>("x") ?: 500, call.argument<Int>("y") ?: 500, (call.argument<Int>("durationMs") ?: 800)) ?: false)
                    "typeText" -> result.success(svc?.typeText(call.argument<String>("text") ?: "", call.argument<String>("hint") ?: "") ?: false)
                    "pressEnter" -> {
                        val r = svc?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK) ?: false
                        result.success(r)
                    }
                    "scroll" -> result.success(svc?.scroll(call.argument<String>("direction") ?: "down") ?: false)
                    "swipe" -> result.success(svc?.swipe(
                        call.argument<Int>("x1") ?: 500, call.argument<Int>("y1") ?: 800,
                        call.argument<Int>("x2") ?: 500, call.argument<Int>("y2") ?: 300,
                        call.argument<Int>("durationMs") ?: 300) ?: false)
                    "pinch" -> result.success(svc?.pinch(
                        call.argument<Int>("x") ?: 500, call.argument<Int>("y") ?: 500,
                        (call.argument<Double>("scale") ?: 1.5).toFloat(),
                        call.argument<Int>("durationMs") ?: 400) ?: false)
                    "pressBack" -> result.success(svc?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK) ?: false)
                    "pressHome" -> result.success(svc?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME) ?: false)
                    "openRecents" -> result.success(svc?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_RECENTS) ?: false)
                    "openNotifications" -> result.success(svc?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS) ?: false)
                    "getCurrentPackage" -> result.success("")
                    "showToast" -> {
                        android.widget.Toast.makeText(this, call.argument<String>("msg") ?: "", android.widget.Toast.LENGTH_SHORT).show()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("NATIVE_ERR", e.message, null)
            }
        }
    }
}