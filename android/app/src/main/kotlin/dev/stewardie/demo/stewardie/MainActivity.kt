package dev.stewardie.demo.stewardie

import io.flutter.embedding.android.FlutterActivity
import android.view.OrientationEventListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.net.Uri

class MainActivity : FlutterActivity() {
    private var listener: OrientationEventListener? = null
    private var sink: EventChannel.EventSink? = null
    private var lastQuadrant = -1
    private var notifications: MethodChannel? = null
    private var pendingNotification: String? = null
    private var sounds: SoundPool? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val activityId = intent.getStringExtra("stewardie_activity") ?: return
        notifications?.invokeMethod("opened", activityId)
        intent.removeExtra("stewardie_activity")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingNotification = intent?.getStringExtra("stewardie_activity")
        intent?.removeExtra("stewardie_activity")
        notifications = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stewardie/notifications")
        val pool = SoundPool.Builder().setMaxStreams(2).setAudioAttributes(AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build()
        sounds = pool
        val loaded = mutableSetOf<Int>()
        pool.setOnLoadCompleteListener { _, id, status -> if (status == 0) loaded.add(id) }
        val cues = mapOf("capture" to pool.load(this, R.raw.capture, 1), "success" to pool.load(this, R.raw.success, 1))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stewardie/sounds").setMethodCallHandler { call, result ->
            val id = cues[call.arguments as? String]
            val audio = getSystemService(AUDIO_SERVICE) as AudioManager
            if (call.method == "play" && id != null && loaded.contains(id) && audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) pool.play(id, .4f, .4f, 1, 0, 1f)
            result.success(null)
        }
        notifications!!.setMethodCallHandler { call, result ->
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                val previous = manager.getNotificationChannel("stewardie_updates")
                val channel = NotificationChannel("stewardie_updates_clay", "Stewardie updates", previous?.importance ?: NotificationManager.IMPORTANCE_HIGH)
                channel.setSound(if (previous != null && previous.sound == null) null else Uri.parse("android.resource://$packageName/${R.raw.notification}"), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
                manager.createNotificationChannel(channel)
            }
            when (call.method) {
                "configure" -> result.success(null)
                "takeInitial" -> { result.success(pendingNotification); pendingNotification = null }
                "clear" -> {
                    manager.activeNotifications.filter {
                        it.tag?.startsWith("stewardie_") == true ||
                        (Build.VERSION.SDK_INT >= 26 && it.notification.channelId == "stewardie_updates")
                    }.forEach { manager.cancel(it.tag, it.id) }
                    result.success(null)
                }
                "show" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val activityId = call.argument<String>("activityId") ?: ""
                    val target = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("stewardie_activity", activityId)
                    }
                    val open = PendingIntent.getActivity(this, id, target, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "stewardie_updates_clay") else Notification.Builder(this).setSound(Uri.parse("android.resource://$packageName/${R.raw.notification}"))
                    builder.setSmallIcon(R.drawable.ic_notification)
                        .setContentTitle("Stewardie").setContentText("You have an update in your space.")
                        .setVisibility(Notification.VISIBILITY_PRIVATE).setAutoCancel(true)
                        .setOnlyAlertOnce(true)
                        .setContentIntent(open)
                    try { manager.notify("stewardie_$activityId", 0, builder.build()); result.success(null) }
                    catch (_: SecurityException) { result.success(null) }
                }
                else -> result.notImplemented()
            }
        }
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
    override fun onDestroy() { sounds?.release(); sounds = null; listener?.disable(); sink = null; super.onDestroy() }
}
