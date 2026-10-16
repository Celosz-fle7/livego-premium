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

        val cryptoChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "livego/netshort_crypto")
        cryptoChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "rsaEncrypt" -> {
                    try {
                        val dataBytes = call.argument<ByteArray>("data") ?: byteArrayOf()
                        val pubKeyB64 = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2poXMstZ8NCWE7915MXzDWC5/t+oB2waGfskPqSZwLqxd4ZBR0H1cb1tAZRZcV7P+LmOd6SYNxhnELaWuKTD+D3xkz8Tt1L5j/ynGqVt1MDbiQIEzXQKUkNDSH6T0A+Xzo/67/8QOQXlVJfW06resbaeNvibfx6Qc78j96bCIPlxPrtieilVTBHUFOXjirxK/ki/mO8P2smRbpt73fsQWdGmTGMfYGvfPApGyxbxLkL/qrBjU25XpM8a0MBqzFWUAchHmqSBJ6Mbfam1SSgf3b2U28s67nOW+JiOrhd6iVLcsLFxXA54HX+Zbej3AbOB6jKaEmp/bz1amneE1NYXwwIDAQAB"
                        val keySpec = java.security.spec.X509EncodedKeySpec(android.util.Base64.decode(pubKeyB64, android.util.Base64.DEFAULT))
                        val keyFactory = java.security.KeyFactory.getInstance("RSA")
                        val publicKey = keyFactory.generatePublic(keySpec)
                        val cipher = javax.crypto.Cipher.getInstance("RSA/ECB/PKCS1Padding")
                        cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, publicKey)
                        val encrypted = cipher.doFinal(dataBytes)
                        result.success(android.util.Base64.encodeToString(encrypted, android.util.Base64.NO_WRAP))
                    } catch (e: Exception) {
                        result.error("RSA_ENCRYPT_ERROR", e.message, null)
                    }
                }
                "rsaDecrypt" -> {
                    try {
                        val cipherBytes = call.argument<ByteArray>("cipherBytes") ?: byteArrayOf()
                        val privKeyB64 = "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCK0Tl1pd7bjTRU93bWoHW1hLCDj2+9bg1MgY8j5C7xXaw6bJfToXhWbH1fXNbnFFVqxyYNErcuOUwJZxyDgcxUXM4yWnRseb2GF97GOicAQ2keDzVYmwky4lrSRwvcXutJRLPUCRQNfc6upfk2G5TKh6/CcP4TV1eXTF7+vdEw2SHxAOITKbSfcaZXr/hVs6a1aRHsBF+7RG99ebwZIP6/AgIyqX9RbDVN6ixi1v2G3/bwAULHLSqGdSaqij/ca17fbFGITaeCeEaZ6d/P4ZuOK+PEPdbPQt6SbY4lZaYwRvdrpH73kigPITgDzIDONFybJ1m7wRKlq1wxWHwbimptAgMBAAECggEAPz3cYJXFtt5YphDrahJGLgEabYVOUc2ub1li/eX54OpdCWzpqneYnD7myyg/m5zu4SuDUVdibsOZuXrpSZw7m3+ATP5apgS8bDe5vTNHC16qqBAjrI9NHIp09/F4HNh9dq6/Am10XkUfgP+KTrU4DyDL2NijV+pltD8N1B5kDE1igokVcsavhnu2INoMRXYE78Wq6urNECuFWw9hldv81M9m2w56t1CQOUukpo4mfmLjZRe2s+kwtcBVefGHP8Cj0OeH2dGltjl2YSQMRBFUCVoixYpOrcjIHoqzWri8IfUZ2tW+nUvHl5IZ9RVxefnFaLGnxiXd2sk6Sn4aD/l9YQKBgQDVv3HaOZxHRqlNSPrNGqplGhE066HnDsq6MlPukiovxE43CRBmpTnk9zDCqrDh9t2HbJuao7nSq5WlBERWgwqXU/qDpH43W7Y/lJfHkDv6A2m0viJa0a9x8+CJpNnCDu1ATo4/IQKwoXYice6JKnUyXgkGKn+HipiN6tO0EtWHlQKBgQCmQfklKFtXtm/FZ6NIMs+d+EyvaE5xNLKGYQxmiCR10WGYd8ZV+K0Q6qXHS+a32TirWB9F3TqPOklTytMrfPZB3BCXj4weEldb8W716G8FYf7LLhaT+MdpF7KDcruObwoQAvKV3N4eX6tUEMmdrx9hpCmmIU5EeXUkhGdmwk7BeQKBgAIXMkThJV8pGMTRvuo8pYgBnkN3PoklAuSZU2rU8Sawc9dj9k4atZtAs7BjvQEoyffmHwt/KHUgCoGnrgdulq7uOlgJRtbBxeGPUYC5L2z9lY4YAfwDawThTsPp4dtdDAMCAbAqYX1axu4FUUD0MltAwjPWPJMVzvIsZs+vE3mVAoGAJPja3OaCmZjadj2709xoyypic0dw2j/ry3JdfZec9A5h87P/CTNJ2U81GoLIhe3qakAohDLUSPGfSOD74NnjMXYswmeLs0xE3Q9tq4XK2pmWPby8DJ/wSHCapByplN0gkbr2E1mQk5SW1xT8oPJGukH1eRpC+3s/D6XaEMH5HZECgYEAigoX5l39LDsCgeaUcI4S9grkaas/WsKv37eqo3oD9Qk6VFiMM5L5Zig6aXJxuAPLVjb38caJRPmPmOXLT2kEP1E1h6OJOhEhETwVIUtcBzsK25ju9LqL89bC+W0uS7BPvk6Tcws/tXHCkQCTgb9jVXceZ2ox+6axvlW/5WgHt5Q="
                        val keySpec = java.security.spec.PKCS8EncodedKeySpec(android.util.Base64.decode(privKeyB64, android.util.Base64.DEFAULT))
                        val keyFactory = java.security.KeyFactory.getInstance("RSA")
                        val privateKey = keyFactory.generatePrivate(keySpec)
                        val cipher = javax.crypto.Cipher.getInstance("RSA/ECB/PKCS1Padding")
                        cipher.init(javax.crypto.Cipher.DECRYPT_MODE, privateKey)
                        val decrypted = cipher.doFinal(cipherBytes)
                        result.success(decrypted)
                    } catch (e: Exception) {
                        result.error("RSA_DECRYPT_ERROR", e.message, null)
                    }
                }
                "aesDecrypt" -> {
                    try {
                        val cipherTextB64 = call.argument<String>("cipherText") ?: ""
                        val keyBytes = call.argument<ByteArray>("key") ?: byteArrayOf()
                        val cipherBytes = android.util.Base64.decode(cipherTextB64, android.util.Base64.DEFAULT)
                        val secretKey = javax.crypto.spec.SecretKeySpec(keyBytes, "AES")
                        val cipher = javax.crypto.Cipher.getInstance("AES/ECB/PKCS7Padding")
                        cipher.init(javax.crypto.Cipher.DECRYPT_MODE, secretKey)
                        val decrypted = cipher.doFinal(cipherBytes)
                        result.success(String(decrypted, Charsets.UTF_8))
                    } catch (e: Exception) {
                        result.error("AES_DECRYPT_ERROR", e.message, null)
                    }
                }
                "aesEncrypt" -> {
                    try {
                        val plainText = call.argument<String>("plainText") ?: ""
                        val keyBytes = call.argument<ByteArray>("key") ?: byteArrayOf()
                        val secretKey = javax.crypto.spec.SecretKeySpec(keyBytes, "AES")
                        val cipher = javax.crypto.Cipher.getInstance("AES/ECB/PKCS7Padding")
                        cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, secretKey)
                        val encrypted = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
                        result.success(android.util.Base64.encodeToString(encrypted, android.util.Base64.NO_WRAP))
                    } catch (e: Exception) {
                        result.error("AES_ENCRYPT_ERROR", e.message, null)
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
