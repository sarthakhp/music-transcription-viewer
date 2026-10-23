package com.sarthak.musictranscriber.music_transcriber

import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingStart: MethodChannel.Result? = null
    private var shareChannel: MethodChannel? = null

    /** A share that arrived before Dart was listening (cold start from the share sheet). */
    @Volatile private var pendingShare: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "music_transcriber/share").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "takeInitial") {
                    result.success(pendingShare)
                    pendingShare = null
                } else {
                    result.notImplemented()
                }
            }
        }
        handleShare(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "music_transcriber/system_audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(Build.VERSION.SDK_INT >= 29)
                    "start" -> {
                        pendingStart = result
                        val manager = getSystemService(MediaProjectionManager::class.java)
                        @Suppress("DEPRECATION")
                        startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_PROJECTION)
                    }
                    "stop" -> stopRecording(result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShare(intent)
    }

    /** Copies a shared file off the main thread, then hands the result to Dart. */
    private fun handleShare(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        // The thread reads its own copy; the original is marked consumed below.
        Log.d("ShareDebug", "handleShare action=${intent.action} type=${intent.type}")
        val share = Intent(intent)
        Thread {
            val result = runCatching { ShareReceiver.parse(this, share) }
            Log.d("ShareDebug", "parsed=${result.getOrNull()} error=${result.exceptionOrNull()}")
            val shared = result.getOrNull()
            if (shared != null) {
                Handler(Looper.getMainLooper()).post { deliverShare(shared) }
            }
        }.start()
        // Mark the intent consumed so a recreated activity doesn't replay it.
        intent.action = Intent.ACTION_MAIN
    }

    private fun deliverShare(shared: Map<String, String>) {
        Log.d("ShareDebug", "deliverShare channelReady=${shareChannel != null}")
        val channel = shareChannel
        if (channel == null) {
            pendingShare = shared
            return
        }
        // If Dart isn't listening yet the call fails, so keep it for takeInitial.
        pendingShare = shared
        channel.invokeMethod("shared", shared, object : MethodChannel.Result {
            override fun success(result: Any?) { Log.d("ShareDebug", "dart accepted"); pendingShare = null }
            override fun error(code: String, message: String?, details: Any?) { Log.d("ShareDebug", "dart error $code $message") }
            override fun notImplemented() { Log.d("ShareDebug", "dart not listening yet") }
        })
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (!SystemAudioService.running) {
            // Already stopped (e.g. from the notification): hand back what we have.
            result.success(mapOf("path" to SystemAudioService.lastPath, "peak" to SystemAudioService.lastPeak))
            return
        }
        SystemAudioService.onStopped = { path, peak ->
            runOnUiThread { result.success(mapOf("path" to path, "peak" to peak)) }
        }
        startService(Intent(this, SystemAudioService::class.java).setAction(SystemAudioService.ACTION_STOP))
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PROJECTION) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingStart
        pendingStart = null
        if (resultCode == RESULT_OK && data != null) {
            val intent = Intent(this, SystemAudioService::class.java)
                .putExtra(SystemAudioService.EXTRA_CODE, resultCode)
                .putExtra(SystemAudioService.EXTRA_DATA, data)
            ContextCompat.startForegroundService(this, intent)
            result?.success(true)
        } else {
            result?.success(false)
        }
    }

    companion object {
        private const val REQUEST_PROJECTION = 4711
    }
}
