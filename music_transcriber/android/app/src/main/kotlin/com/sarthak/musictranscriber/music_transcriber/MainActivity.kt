package com.sarthak.musictranscriber.music_transcriber

import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingStart: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
