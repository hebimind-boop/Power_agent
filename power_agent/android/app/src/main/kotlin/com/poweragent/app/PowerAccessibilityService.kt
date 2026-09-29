package com.poweragent.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.util.DisplayMetrics
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.Base64
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

class PowerAccessibilityService : AccessibilityService() {

    companion object {
        var instance: PowerAccessibilityService? = null
    }

    override fun onServiceConnected() { instance = this }
    override fun onUnbind(intent: android.content.Intent?): Boolean { instance = null; return super.onUnbind(intent) }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    private fun size(): Pair<Int, Int> {
        val m = resources.displayMetrics
        return m.widthPixels to m.heightPixels
    }
    private fun toPx(x1000: Int, y1000: Int): Pair<Int, Int> {
        val (w, h) = size()
        return ((x1000.coerceIn(0, 1000) / 1000f * w).roundToInt() to
                (y1000.coerceIn(0, 1000) / 1000f * h).roundToInt())
    }

    fun dumpScreen(): String {
        val arr = JSONArray()
        val wins = windows ?: return "[]"
        var idx = 0
        for (w in wins) {
            if (w.type != android.view.accessibility.AccessibilityWindowInfo.TYPE_APPLICATION) continue
            traverse(w.root, arr, 0) { idx++ }
        }
        return arr.toString()
    }

    private fun traverse(n: AccessibilityNodeInfo?, arr: JSONArray, depth: Int, next: () -> Int) {
        if (n == null || depth > 12) return
        val b = Rect()
        n.getBoundsInScreen(b)
        if (!n.isVisibleToUser || b.isEmpty) { for (i in 0 until n.childCount) traverse(n.getChild(i), arr, depth + 1, next); return }
        val text = (n.text?.toString() ?: "") + " " + (n.contentDescription?.toString() ?: "")
        if (text.isBlank() && !n.isClickable && !n.isEditable && !n.isScrollable) {
            for (i in 0 until n.childCount) traverse(n.getChild(i), arr, depth + 1, next)
            return
        }
        val (w, h) = size()
        val o = JSONObject()
        o.put("index", next())
        o.put("text", text.trim().take(80))
        o.put("clickable", n.isClickable)
        o.put("editable", n.isEditable)
        o.put("scrollable", n.isScrollable)
        o.put("x1000", ((b.centerX().coerceIn(0, w)) / w.toFloat() * 1000).roundToInt())
        o.put("y1000", ((b.centerY().coerceIn(0, h)) / h.toFloat() * 1000).roundToInt())
        arr.put(o)
        for (i in 0 until n.childCount) traverse(n.getChild(i), arr, depth + 1, next)
    }

    fun takeScreenshotBase64(): String? {
        if (Build.VERSION.SDK_INT < 30) return null
        var out: String? = null
        val latch = CountDownLatch(1)
        takeScreenshot(Display.DEFAULT_DISPLAY, mainExecutor, object : TakeScreenshotCallback {
            override fun onSuccess(s: ScreenshotResult) {
                try {
                    val bmp = Bitmap.wrapHardwareBuffer(s.hardwareBuffer, s.colorSpace)
                    if (bmp != null) {
                        val c = bmp.copy(Bitmap.Config.ARGB_8888, false)
                        val bos = ByteArrayOutputStream()
                        val scaled = if (c.width > 768) Bitmap.createScaledBitmap(c, 768, (768f / c.width * c.height).roundToInt(), true) else c
                        scaled.compress(Bitmap.CompressFormat.JPEG, 55, bos)
                        out = Base64.getEncoder().encodeToString(bos.toByteArray())
                    }
                } catch (_: Exception) {} finally { latch.countDown() }
            }
            override fun onFailure(code: Int) { latch.countDown() }
        })
        latch.await(4, TimeUnit.SECONDS)
        return out
    }

    private fun tap(x: Int, y: Int, dur: Long): Boolean {
        val (px, py) = toPx(x, y)
        val p = Path().apply { moveTo(px.toFloat(), py.toFloat()) }
        val g = GestureDescription.Builder().addStroke(GestureDescription.StrokeDescription(p, 0, dur)).build()
        var ok = false
        val latch = CountDownLatch(1)
        dispatchGesture(g, object : GestureResultCallback() {
            override fun onCompleted(g: GestureDescription?) { ok = true; latch.countDown() }
            override fun onCancelled(g: GestureDescription?) { latch.countDown() }
        }, null)
        latch.await(3, TimeUnit.SECONDS)
        return ok
    }

    fun clickAt(x: Int, y: Int) = tap(x, y, 80)
    fun doubleTap(x: Int, y: Int): Boolean {
        val (px, py) = toPx(x, y)
        val p = Path().apply { moveTo(px.toFloat(), py.toFloat()) }
        val g = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(p, 0, 60))
            .addStroke(GestureDescription.StrokeDescription(p, 180, 60))
            .build()
        var ok = false
        val latch = CountDownLatch(1)
        dispatchGesture(g, object : GestureResultCallback() {
            override fun onCompleted(g: GestureDescription?) { ok = true; latch.countDown() }
            override fun onCancelled(g: GestureDescription?) { latch.countDown() }
        }, null)
        latch.await(3, TimeUnit.SECONDS)
        return ok
    }

    fun longPress(x: Int, y: Int, durMs: Int) = tap(x, y, durMs.coerceIn(300, 3000).toLong())

    fun pinch(x: Int, y: Int, scale: Float, durMs: Int): Boolean {
        val (px, py) = toPx(x, y)
        val d = (120 * (if (scale >= 1) scale else 1 / scale)).coerceIn(80f, 400f)
        val p1 = Path().apply { moveTo(px - d, py.toFloat()); lineTo(px - d * (if (scale >= 1) 1.6f else 0.4f), py.toFloat()) }
        val p2 = Path().apply { moveTo(px + d, py.toFloat()); lineTo(px + d * (if (scale >= 1) 1.6f else 0.4f), py.toFloat()) }
        val g = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(p1, 0, durMs.toLong()))
            .addStroke(GestureDescription.StrokeDescription(p2, 0, durMs.toLong()))
            .build()
        var ok = false
        val latch = CountDownLatch(1)
        dispatchGesture(g, object : GestureResultCallback() {
            override fun onCompleted(g: GestureDescription?) { ok = true; latch.countDown() }
            override fun onCancelled(g: GestureDescription?) { latch.countDown() }
        }, null)
        latch.await(3, TimeUnit.SECONDS)
        return ok
    }

    fun swipe(x1: Int, y1: Int, x2: Int, y2: Int, durMs: Int): Boolean {
        val (a, b) = toPx(x1, y1); val (c, d) = toPx(x2, y2)
        val p = Path().apply { moveTo(a.toFloat(), b.toFloat()); lineTo(c.toFloat(), d.toFloat()) }
        val g = GestureDescription.Builder().addStroke(GestureDescription.StrokeDescription(p, 0, durMs.coerceIn(100, 2000).toLong())).build()
        var ok = false
        val latch = CountDownLatch(1)
        dispatchGesture(g, object : GestureResultCallback() {
            override fun onCompleted(g: GestureDescription?) { ok = true; latch.countDown() }
            override fun onCancelled(g: GestureDescription?) { latch.countDown() }
        }, null)
        latch.await(3, TimeUnit.SECONDS)
        return ok
    }

    private fun findNodes(pred: (AccessibilityNodeInfo) -> Boolean): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        val wins = windows ?: return out
        for (w in wins) {
            val r = w.root ?: continue
            val q = java.util.ArrayDeque<AccessibilityNodeInfo>(); q.add(r)
            while (q.isNotEmpty()) {
                val n = q.removeFirst()
                try { if (pred(n)) out.add(n) } catch (_: Exception) {}
                for (i in 0 until n.childCount) n.getChild(i)?.let { q.add(it) }
            }
        }
        return out
    }

    fun clickByText(text: String): Boolean {
        val q = text.trim()
        if (q.isEmpty()) return false
        val cands = findNodes { n ->
            val t = "${n.text ?: ""} ${n.contentDescription ?: ""}"
            t == q || t.contains(q) || t.lowercase().contains(q.lowercase())
        }.filter { it.isVisibleToUser }
        for (n in cands.sortedBy { if (it.isClickable) 0 else 1 }) {
            var c: AccessibilityNodeInfo? = n
            while (c != null) {
                if (c.isClickable) {
                    if (c.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true
                    break
                }
                c = c.parent
            }
        }
        val first = cands.firstOrNull() ?: return false
        val b = Rect(); first.getBoundsInScreen(b)
        if (b.isEmpty) return false
        val (w, h) = size()
        return tap(((b.centerX() / w.toFloat() * 1000).roundToInt()), ((b.centerY() / h.toFloat() * 1000).roundToInt()), 80)
    }

    fun typeText(text: String, hint: String): Boolean {
        val editables = findNodes { it.isEditable && it.isVisibleToUser }
        val target = if (hint.isNotBlank()) editables.firstOrNull {
            "${it.text ?: ""} ${it.contentDescription ?: ""} ${it.hintText ?: ""}".lowercase().contains(hint.lowercase())
        } ?: editables.firstOrNull() else editables.firstOrNull() ?: return false
        target.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val args = android.os.Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun scroll(dir: String): Boolean {
        val nodes = findNodes { it.isScrollable && it.isVisibleToUser }
        val n = nodes.firstOrNull() ?: return false
        val act = if (dir.lowercase() in listOf("up", "left", "backward")) AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD else AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        return n.performAction(act)
    }
}