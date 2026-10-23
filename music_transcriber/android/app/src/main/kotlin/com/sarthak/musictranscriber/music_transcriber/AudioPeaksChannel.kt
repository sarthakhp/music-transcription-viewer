package com.sarthak.musictranscriber.music_transcriber

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Loudness outline of any audio file Android can decode (mp3, m4a, ogg, flac...),
 * for the trim view's waveform. Decoding streams through the platform codec and
 * keeps only one peak per bucket, so the audio is never held in memory.
 */
object AudioPeaksChannel {
    private const val CHANNEL = "music_transcriber/audio_peaks"
    private const val TIMEOUT_US = 10_000L

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "peaks") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val buckets = call.argument<Int>("buckets") ?: 160
            if (path == null) {
                result.error("bad_args", "path is required", null)
                return@setMethodCallHandler
            }
            Thread {
                val peaks = runCatching { compute(path, buckets) }.getOrNull()
                Handler(Looper.getMainLooper()).post { result.success(peaks?.toList()) }
            }.start()
        }
    }

    /** Peaks in 0..1, one per bucket, or null if the file has no decodable audio. */
    private fun compute(path: String, buckets: Int): DoubleArray? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return null
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
            if (durationUs <= 0) return null

            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()
            return decode(extractor, codec, durationUs, buckets)
        } finally {
            codec?.let { runCatching { it.stop() }; it.release() }
            extractor.release()
        }
    }

    private fun decode(extractor: MediaExtractor, codec: MediaCodec, durationUs: Long, buckets: Int): DoubleArray {
        val peaks = DoubleArray(buckets)
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false

        while (!outputDone) {
            if (!inputDone) inputDone = feedInput(extractor, codec)

            val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            if (index < 0) continue

            val format = codec.outputFormat
            val channels = max(1, format.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val samples = codec.getOutputBuffer(index)!!.order(ByteOrder.nativeOrder()).asShortBuffer()
            addPeaks(peaks, samples, channels, sampleRate, info.presentationTimeUs, durationUs)

            codec.releaseOutputBuffer(index, false)
            outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
        }
        return peaks
    }

    /** Queues the next chunk of the file into the codec; returns true once the file is exhausted. */
    private fun feedInput(extractor: MediaExtractor, codec: MediaCodec): Boolean {
        val index = codec.dequeueInputBuffer(TIMEOUT_US)
        if (index < 0) return false
        val size = extractor.readSampleData(codec.getInputBuffer(index)!!, 0)
        if (size < 0) {
            codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            return true
        }
        codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
        extractor.advance()
        return false
    }

    /** Folds one decoded buffer into [peaks], placing each frame by its time in the file. */
    private fun addPeaks(
        peaks: DoubleArray,
        samples: java.nio.ShortBuffer,
        channels: Int,
        sampleRate: Int,
        bufferStartUs: Long,
        durationUs: Long,
    ) {
        val frames = samples.remaining() / channels
        for (frame in 0 until frames) {
            val timeUs = bufferStartUs + frame * 1_000_000L / sampleRate
            val bucket = min(peaks.size - 1, max(0, (timeUs * peaks.size / durationUs).toInt()))
            var loudest = 0
            for (channel in 0 until channels) {
                loudest = max(loudest, abs(samples.get(frame * channels + channel).toInt()))
            }
            peaks[bucket] = max(peaks[bucket], loudest / 32768.0)
        }
    }
}
