package com.sarthak.musictranscriber.music_transcriber

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import kotlin.math.abs

/**
 * Records what other apps are playing (Android 10+ playback capture) into a
 * mono 16-bit WAV. Runs as a foreground service of type mediaProjection, which
 * Android requires while a projection is active. Apps can opt out of being
 * captured; in that case the recording is silent (reported through `peak`).
 */
class SystemAudioService : Service() {
    companion object {
        const val ACTION_STOP = "music_transcriber.STOP_SYSTEM_AUDIO"
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        const val SAMPLE_RATE = 44100
        private const val CHANNEL_ID = "system_audio"
        private const val NOTIFICATION_ID = 4711

        @Volatile var running = false
        @Volatile var lastPath: String? = null
        @Volatile var lastPeak = 0
        var onStopped: ((String?, Int) -> Unit)? = null
    }

    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    private var worker: Thread? = null
    private var pcmFile: File? = null
    @Volatile private var peak = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finish()
            return START_NOT_STICKY
        }
        if (running) return START_NOT_STICKY
        startInForeground()

        val code = intent?.getIntExtra(EXTRA_CODE, 0) ?: 0
        @Suppress("DEPRECATION")
        val data = intent?.getParcelableExtra<Intent>(EXTRA_DATA)
        if (data == null) {
            finish()
            return START_NOT_STICKY
        }
        val manager = getSystemService(MediaProjectionManager::class.java)
        val projection = manager.getMediaProjection(code, data)
        if (projection == null) {
            finish()
            return START_NOT_STICKY
        }
        // Android 14+ requires a callback to be registered before capturing.
        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() = finish()
        }, Handler(Looper.getMainLooper()))
        this.projection = projection

        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
            .build()
        val bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        ) * 4
        val audioRecord = AudioRecord.Builder()
            .setAudioFormat(format)
            .setAudioPlaybackCaptureConfig(config)
            .setBufferSizeInBytes(bufferSize)
            .build()
        record = audioRecord

        val file = File(cacheDir, "system_audio_${System.currentTimeMillis()}.pcm")
        pcmFile = file
        peak = 0
        running = true
        audioRecord.startRecording()
        worker = Thread {
            val buffer = ShortArray(bufferSize / 2)
            FileOutputStream(file).use { out ->
                val bytes = ByteArray(buffer.size * 2)
                while (running) {
                    val n = audioRecord.read(buffer, 0, buffer.size)
                    if (n <= 0) continue
                    for (i in 0 until n) {
                        val s = buffer[i].toInt()
                        if (abs(s) > peak) peak = abs(s)
                        bytes[2 * i] = (s and 0xFF).toByte()
                        bytes[2 * i + 1] = ((s shr 8) and 0xFF).toByte()
                    }
                    out.write(bytes, 0, n * 2)
                }
            }
        }.also { it.start() }
        return START_NOT_STICKY
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Phone audio recording", NotificationManager.IMPORTANCE_LOW)
        )
        val stop = PendingIntent.getService(
            this, 0,
            Intent(this, SystemAudioService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Recording phone audio")
            .setContentText("Tap Stop when the song is done")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @Synchronized
    private fun finish() {
        val wasRunning = running
        running = false
        worker?.join(2000)
        worker = null
        record?.let { runCatching { it.stop() }; it.release() }
        record = null
        projection?.stop()
        projection = null

        var path: String? = null
        val pcm = pcmFile
        if (wasRunning && pcm != null && pcm.exists()) {
            val wav = File(cacheDir, pcm.nameWithoutExtension + ".wav")
            writeWav(pcm, wav)
            pcm.delete()
            path = wav.absolutePath
            lastPath = path
            lastPeak = peak
        }
        pcmFile = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        if (wasRunning) onStopped?.invoke(path, peak)
    }

    private fun writeWav(pcm: File, wav: File) {
        val dataLen = pcm.length().toInt()
        RandomAccessFile(wav, "rw").use { out ->
            fun int(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte())
            fun short(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte())
            out.write("RIFF".toByteArray()); out.write(int(36 + dataLen))
            out.write("WAVEfmt ".toByteArray()); out.write(int(16))
            out.write(short(1)); out.write(short(1))
            out.write(int(SAMPLE_RATE)); out.write(int(SAMPLE_RATE * 2))
            out.write(short(2)); out.write(short(16))
            out.write("data".toByteArray()); out.write(int(dataLen))
            pcm.inputStream().use { input ->
                val chunk = ByteArray(64 * 1024)
                while (true) {
                    val n = input.read(chunk)
                    if (n < 0) break
                    out.write(chunk, 0, n)
                }
            }
        }
    }

    override fun onDestroy() {
        finish()
        super.onDestroy()
    }
}
