package com.livego.premium

import android.content.ContentValues
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val debugFileChannel = "livego/debug_file"

    private fun forceBlackWindow() {
        window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        forceBlackWindow()
        super.onCreate(savedInstanceState)
        forceBlackWindow()
    }

    override fun onResume() {
        super.onResume()
        forceBlackWindow()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, debugFileChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveDebugLog") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val fileName = call.argument<String>("fileName") ?: "livego_debug_record.txt"
                val content = call.argument<String>("content") ?: ""

                try {
                    val savedPath = saveDebugLog(fileName, content)
                    result.success(savedPath)
                } catch (error: Throwable) {
                    result.error("SAVE_DEBUG_LOG_FAILED", error.message, null)
                }
            }
    }

    private fun cleanFileName(raw: String): String {
        val clean = raw.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return if (clean.isBlank()) "livego_debug_record.txt" else clean
    }

    private fun saveDebugLog(rawFileName: String, content: String): String {
        val safeFileName = cleanFileName(rawFileName)

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveDebugLogMediaStore(safeFileName, content)
        } else {
            saveDebugLogLegacy(safeFileName, content)
        }
    }

    private fun saveDebugLogMediaStore(fileName: String, content: String): String {
        val resolver = applicationContext.contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/LiveGoDebug"

        // Keep one latest file, not hundreds of duplicates.
        resolver.delete(
            collection,
            "${MediaStore.Downloads.DISPLAY_NAME}=? AND ${MediaStore.Downloads.RELATIVE_PATH}=?",
            arrayOf(fileName, "$relativePath/")
        )

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "text/plain")
            put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore insert returned null")

        resolver.openOutputStream(uri, "w")?.use { stream ->
            stream.write(content.toByteArray(Charsets.UTF_8))
            stream.flush()
        } ?: throw IllegalStateException("MediaStore output stream returned null")

        val done = ContentValues().apply {
            put(MediaStore.Downloads.IS_PENDING, 0)
        }
        resolver.update(uri, done, null, null)

        return "Download/LiveGoDebug/$fileName"
    }

    private fun saveDebugLogLegacy(fileName: String, content: String): String {
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val dir = File(downloads, "LiveGoDebug")
        if (!dir.exists()) dir.mkdirs()

        val file = File(dir, fileName)
        file.writeText(content, Charsets.UTF_8)

        return file.absolutePath
    }
}
