package com.livego.premium

import android.app.UiModeManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val nativePlayerChannelName = "livego/native_surface_player"
    private val updaterChannelName = "livego/app_updater"
    private val runtimeChannelName = "livego/runtime"
    private val cinemaSessionChannelName = "livego/cinema_session"

    companion object {
        var nativePlayerChannel: MethodChannel? = null
    }

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

    private fun isTvRuntime(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        val isTelevisionMode = uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        val hasLeanback = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY)
        return isTelevisionMode || hasLeanback
    }

    private fun appInfoMap(): Map<String, Any?> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }

        return mapOf(
            "versionName" to (info.versionName ?: ""),
            "versionCode" to code
        )
    }

    private fun openApkInstaller(path: String) {
        val apk = File(path)
        if (!apk.exists()) {
            throw IllegalArgumentException("APK update tidak ditemukan")
        }

        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativePlayerChannelName)
        nativePlayerChannel = channel

        channel.setMethodCallHandler { call, result ->
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
                        putExtra("chapterId", call.argument<String>("chapterId").orEmpty())
                        putExtra("playbackKey", call.argument<String>("playbackKey").orEmpty())
                        putExtra("totalEpisodes", totalEpisodes)
                        putExtra("autoNextEnabled", call.argument<Boolean>("autoNextEnabled") ?: true)
                        putExtra("selectedQuality", call.argument<String>("selectedQuality").orEmpty())
                        putExtra("selectedSubtitle", call.argument<String>("selectedSubtitle").orEmpty())
                        putExtra("selectedAudio", call.argument<String>("selectedAudio").orEmpty())
                        putExtra("selectedSpeed", call.argument<Double>("selectedSpeed") ?: 1.0)
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

        val runtimeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, runtimeChannelName)
        runtimeChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isTvRuntime" -> result.success(isTvRuntime())
                else -> result.notImplemented()
            }
        }

        val updaterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannelName)
        updaterChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppInfo" -> result.success(appInfoMap())

                "installApk" -> {
                    val path = call.argument<String>("path").orEmpty()
                    try {
                        openApkInstaller(path)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("INSTALL_APK_FAILED", e.message ?: "Gagal membuka installer APK", null)
                    }
                }

                "canRequestPackageInstalls" -> {
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(allowed)
                }

                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                            startActivity(intent)
                        } catch (e: ActivityNotFoundException) {
                            try {
                                val fallbackIntent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallbackIntent)
                            } catch (ignored: Exception) {
                            }
                        } catch (ignored: Exception) {
                        }
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        val cinemaSessionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cinemaSessionChannelName)
        cinemaSessionChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCinemaIdSession" -> {
                    try {
                        val cinemaCtx = createPackageContext("com.movieph.bj.playvibes", Context.CONTEXT_IGNORE_SECURITY)
                        val sp = cinemaCtx.getSharedPreferences("default_sp", Context.MODE_PRIVATE)
                        val deviceSp = cinemaCtx.getSharedPreferences("deviceId", Context.MODE_PRIVATE)
                        val session = mapOf(
                            "token" to (sp.getString("KEY_PREF_USER_TOKEN", "") ?: ""),
                            "userId" to (sp.getInt("KEY_PREF_USER_ID", 0).toString()),
                            "deviceId" to (deviceSp.getString("key", "") ?: ""),
                            "isSvip" to sp.getInt("KEY_PREF_USER_IS_SVIP", 0).toString(),
                            "baseUrl" to (sp.getString("KEY_PREF_BASE_URL40000", "") ?: ""),
                            "domainList" to (sp.getString("CACHE_DOMAIN_LIST", "") ?: "")
                        )
                        result.success(session)
                    } catch (e: Exception) {
                        result.error("SESSION_READ_FAILED", e.message ?: "Gagal membaca session CinemaID", null)
                    }
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

    override fun onDestroy() {
        if (isFinishing) nativePlayerChannel = null
        super.onDestroy()
    }
}
