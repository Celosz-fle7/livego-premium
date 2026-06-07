package com.livego.premium

import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val nativePlayerChannel = "livego/native_surface_player"

    private fun forceBlackWindow() {
        window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
    }

    private fun stringListArg(call: io.flutter.plugin.common.MethodCall, name: String): ArrayList<String> {
        val raw = call.argument<List<Any>>(name) ?: emptyList()
        val out = ArrayList<String>()
        raw.forEach { out.add(it.toString()) }
        return out
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativePlayerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val url = call.argument<String>("url").orEmpty()
                        if (url.isBlank()) {
                            result.error("EMPTY_URL", "Native player URL is empty", null)
                            return@setMethodCallHandler
                        }

                        val title = call.argument<String>("title").orEmpty()
                        val episode = call.argument<Int>("episode") ?: 1
                        val totalEpisodes = call.argument<Int>("totalEpisodes") ?: 0
                        val headersAny = call.argument<Map<String, Any>>("headers") ?: emptyMap()

                        val headerKeys = ArrayList<String>()
                        val headerValues = ArrayList<String>()
                        headersAny.forEach { (key, value) ->
                            val v = value.toString()
                            if (key.isNotBlank() && v.isNotBlank()) {
                                headerKeys.add(key)
                                headerValues.add(v)
                            }
                        }

                        val intent = Intent(this, TvNativeSurfacePlayerActivity::class.java).apply {
                            putExtra("url", url)
                            putExtra("title", title)
                            putExtra("description", call.argument<String>("description").orEmpty())
                            putExtra("source", call.argument<String>("source").orEmpty())
                            putExtra("category", call.argument<String>("category").orEmpty())
                            putExtra("episode", episode)
                            putExtra("totalEpisodes", totalEpisodes)
                            putStringArrayListExtra("headerKeys", headerKeys)
                            putStringArrayListExtra("headerValues", headerValues)
                            putStringArrayListExtra("qualityLabels", stringListArg(call, "qualityLabels"))
                            putStringArrayListExtra("qualityUrls", stringListArg(call, "qualityUrls"))
                            putStringArrayListExtra("subtitleLabels", stringListArg(call, "subtitleLabels"))
                            putStringArrayListExtra("subtitleUrls", stringListArg(call, "subtitleUrls"))
                            putStringArrayListExtra("subtitleFormats", stringListArg(call, "subtitleFormats"))
                            addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
                        }
                        startActivity(intent)
                        overridePendingTransition(0, 0)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
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
}
