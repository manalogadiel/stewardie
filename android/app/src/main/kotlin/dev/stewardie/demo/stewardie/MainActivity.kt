package dev.stewardie.demo.stewardie

import io.flutter.embedding.android.FlutterActivity
import android.view.OrientationEventListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var listener: OrientationEventListener? = null
    private var sink: EventChannel.EventSink? = null
    private var lastQuadrant = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "stewardie/device_orientation")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sink = events
                    lastQuadrant = -1
                    listener = object : OrientationEventListener(this@MainActivity) {
                        override fun onOrientationChanged(angle: Int) {
                            if (angle == ORIENTATION_UNKNOWN) return
                            val quadrant = ((angle + 45) / 90) % 4
                            // Ignore boundary jitter; positions never depend on this signal.
                            val center = quadrant * 90
                            val distance = kotlin.math.abs(angle - center).let { kotlin.math.min(it, 360 - it) }
                            if (distance > 30 || quadrant == lastQuadrant) return
                            lastQuadrant = quadrant
                            val turns = when (quadrant) { 1 -> -0.25; 2 -> 0.5; 3 -> 0.25; else -> 0.0 }
                            sink?.success(turns)
                        }
                    }
                    listener?.enable()
                }
                override fun onCancel(arguments: Any?) {
                    listener?.disable()
                    listener = null
                    sink = null
                }
            })
    }
    override fun onPause() { listener?.disable(); super.onPause() }
    override fun onResume() { super.onResume(); if (sink != null) listener?.enable() }
    override fun onDestroy() { listener?.disable(); sink = null; super.onDestroy() }
}
