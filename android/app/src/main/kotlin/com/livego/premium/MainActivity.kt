package com.livego.premium

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPlayerResult: MethodChannel.Result? = null

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "livego/native_player"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNativePlayer" -> openNativePlayer(call.arguments, result)
                "openNativeBlackTest" -> openNativeBlackTest(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun openNativeBlackTest(result: MethodChannel.Result) {
        if (pendingPlayerResult != null) {
            result.error("PLAYER_BUSY", "Native player is already open", null)
            return
        }

        pendingPlayerResult = result
        startActivityForResult(
            Intent(this, TvNativeBlackTestActivity::class.java),
            REQUEST_NATIVE_PLAYER
        )
    }

    private fun openNativePlayer(arguments: Any?, result: MethodChannel.Result) {
        if (pendingPlayerResult != null) {
            result.error("PLAYER_BUSY", "Native player is already open", null)
            return
        }

        val args = arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val url = args["url"] as? String ?: ""
        if (url.isBlank()) {
            result.error("PLAYER_URL_EMPTY", "Native player URL is empty", null)
            return
        }

        val intent = Intent(this, TvNativePlayerActivity::class.java).apply {
            putExtra("url", url)
            putExtra("title", args["title"] as? String ?: "LiveGO")
            putExtra("episode", (args["episode"] as? Number)?.toInt() ?: 1)
            putExtra("quality", args["quality"] as? String ?: "Auto")
            putExtra("headers", args["headers"] as? String ?: "{}")
            putExtra("platformSlug", args["platformSlug"] as? String ?: "")
            putExtra("contentId", args["contentId"] as? String ?: "")
            putExtra("totalEpisodes", (args["totalEpisodes"] as? Number)?.toInt() ?: 1)
        }

        pendingPlayerResult = result
        startActivityForResult(intent, REQUEST_NATIVE_PLAYER)
    }

    @Deprecated("Deprecated in Android API, still fine for FlutterActivity bridge here.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_NATIVE_PLAYER) {
            pendingPlayerResult?.success(
                mapOf(
                    "closed" to true,
                    "resultCode" to resultCode
                )
            )
            pendingPlayerResult = null
            forceBlackWindow()
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val REQUEST_NATIVE_PLAYER = 7701
    }
}
