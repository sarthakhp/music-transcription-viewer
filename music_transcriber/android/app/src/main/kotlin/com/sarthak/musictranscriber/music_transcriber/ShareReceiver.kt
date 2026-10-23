package com.sarthak.musictranscriber.music_transcriber

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import java.io.File

/**
 * Turns an Android share intent (audio file or text containing a link) into a
 * plain map for Dart. Shared files are copied into the app's cache, because the
 * content:// permission lasts only as long as the receiving activity.
 */
object ShareReceiver {
    private val linkPattern = Regex("https?://\\S+")

    /** Returns a map for Dart, or null if [intent] isn't a share we handle. */
    fun parse(context: Context, intent: Intent?): Map<String, String>? {
        if (intent?.action != Intent.ACTION_SEND) return null
        val type = intent.type ?: return null
        return when {
            type.startsWith("audio/") -> copySharedFile(context, intent)
            type == "text/plain" -> linkFrom(intent)
            else -> null
        }
    }

    private fun linkFrom(intent: Intent): Map<String, String>? {
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        val url = linkPattern.find(text)?.value ?: return null
        return mapOf("type" to "link", "url" to url)
    }

    private fun copySharedFile(context: Context, intent: Intent): Map<String, String>? {
        val uri: Uri = streamExtra(intent) ?: return null
        val name = displayName(context.contentResolver, uri)
        val target = File(context.cacheDir, "shared_${System.currentTimeMillis()}_$name")
        context.contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        return mapOf("type" to "audio", "path" to target.absolutePath, "name" to name)
    }

    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    private fun displayName(resolver: ContentResolver, uri: Uri): String {
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val name = cursor.getString(0)
                if (!name.isNullOrBlank()) return name
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "shared_audio"
    }
}
