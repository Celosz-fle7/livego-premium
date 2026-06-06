package com.example.livego_premium

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

class TvNativePlayerActivity : Activity() {
    private var player: ExoPlayer? = null
    private lateinit var root: FrameLayout
    private lateinit var playerView: PlayerView
    private lateinit var topInfo: TextView
    private lateinit var bottomInfo: TextView
    private lateinit var centerStatus: TextView

    private val handler = Handler(Looper.getMainLooper())
    private var controlsVisible = true
    private var title = "LiveGO"
    private var episode = 1
    private var totalEpisodes = 1
    private var quality = "Auto"

    private val hideControlsRunnable = Runnable {
        hideControls()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forceBlackWindow()
        readIntent()
        buildUi()
        setupPlayer()
    }

    override fun onResume() {
        super.onResume()
        forceBlackWindow()
        immersive()
    }

    override fun onPause() {
        super.onPause()
        player?.pause()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        playerView.player = null
        player?.release()
        player = null
        super.onDestroy()
    }

    private fun readIntent() {
        title = intent.getStringExtra("title") ?: "LiveGO"
        episode = intent.getIntExtra("episode", 1)
        totalEpisodes = intent.getIntExtra("totalEpisodes", 1).coerceAtLeast(1)
        quality = intent.getStringExtra("quality") ?: "Auto"
    }

    private fun forceBlackWindow() {
        window.setBackgroundDrawableResource(android.R.color.black)
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        immersive()
    }

    private fun immersive() {
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    private fun buildUi() {
        root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            isFocusable = true
            isFocusableInTouchMode = true
        }

        playerView = PlayerView(this).apply {
            setBackgroundColor(Color.BLACK)
            setShutterBackgroundColor(Color.BLACK)
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
            keepScreenOn = true
        }

        topInfo = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            setShadowLayer(8f, 0f, 2f, Color.BLACK)
            maxLines = 1
            text = title
        }

        bottomInfo = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setBackgroundColor(0x99000000.toInt())
            setPadding(24, 14, 24, 14)
            text = controlsText()
        }

        centerStatus = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setBackgroundColor(0x99000000.toInt())
            setPadding(28, 20, 28, 20)
            text = "Menyiapkan video..."
        }

        root.addView(playerView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        ))

        root.addView(topInfo, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP
        ).apply {
            leftMargin = 56
            rightMargin = 56
            topMargin = 36
        })

        root.addView(centerStatus, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        ))

        root.addView(bottomInfo, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        ).apply {
            bottomMargin = 42
        })

        setContentView(root)
        root.requestFocus()
        showControls("Menyiapkan video...")
    }

    private fun setupPlayer() {
        val url = intent.getStringExtra("url") ?: ""
        if (url.isBlank()) {
            showControls("URL video kosong")
            return
        }

        val headers = parseHeaders(intent.getStringExtra("headers") ?: "{}")
        if (!headers.containsKey("User-Agent")) {
            headers["User-Agent"] = "okhttp/4.12.0"
        }
        if (!headers.containsKey("Accept")) {
            headers["Accept"] = "*/*"
        }

        val httpFactory = DefaultHttpDataSource.Factory()
            .setUserAgent(headers["User-Agent"])
            .setDefaultRequestProperties(headers)

        val mediaSourceFactory = DefaultMediaSourceFactory(httpFactory)

        val exo = ExoPlayer.Builder(this)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()

        player = exo
        playerView.player = exo

        exo.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_BUFFERING -> showControls("Buffering...")
                    Player.STATE_READY -> {
                        centerStatus.visibility = View.GONE
                        showControls("Memutar Episode $episode")
                    }
                    Player.STATE_ENDED -> showControls("Episode selesai")
                    Player.STATE_IDLE -> showControls("Player idle")
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                showControls("Gagal memutar video")
                centerStatus.visibility = View.VISIBLE
                centerStatus.text = "Gagal memutar video\n${error.errorCodeName}"
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                refreshBottomText()
            }
        })

        exo.setMediaItem(MediaItem.fromUri(url))
        exo.prepare()
        exo.playWhenReady = true
    }

    private fun parseHeaders(raw: String): MutableMap<String, String> {
        val map = mutableMapOf<String, String>()
        try {
            val json = JSONObject(raw)
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val value = json.optString(key, "")
                if (key.isNotBlank() && value.isNotBlank()) map[key] = value
            }
        } catch (_: Exception) {
        }
        return map
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val repeated = event?.repeatCount ?: 0
        if (repeated > 0 && isActivationKey(keyCode)) return true

        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_SPACE -> {
                togglePlay()
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_MEDIA_REWIND -> {
                seekBy(-10_000L)
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                seekBy(10_000L)
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP -> {
                showControls("Kontrol Player")
                return true
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                showControls("Episode panel native masuk batch berikutnya")
                return true
            }
            KeyEvent.KEYCODE_MENU -> {
                showControls("Quality/Subtitle native masuk batch berikutnya")
                return true
            }
            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_ESCAPE -> {
                if (controlsVisible) {
                    hideControls()
                } else {
                    setResult(RESULT_OK)
                    finish()
                }
                return true
            }
        }

        return super.onKeyDown(keyCode, event)
    }

    private fun isActivationKey(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_DPAD_CENTER ||
            keyCode == KeyEvent.KEYCODE_ENTER ||
            keyCode == KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE ||
            keyCode == KeyEvent.KEYCODE_BACK ||
            keyCode == KeyEvent.KEYCODE_MENU
    }

    private fun togglePlay() {
        val p = player ?: return
        if (p.isPlaying) {
            p.pause()
            showControls("Pause")
        } else {
            p.play()
            showControls("Play")
        }
    }

    private fun seekBy(deltaMs: Long) {
        val p = player ?: return
        val duration = if (p.duration > 0) p.duration else Long.MAX_VALUE
        val target = min(max(0L, p.currentPosition + deltaMs), duration)
        p.seekTo(target)
        val sign = if (deltaMs < 0) "-" else "+"
        showControls("$sign${kotlin.math.abs(deltaMs / 1000)} detik")
    }

    private fun showControls(message: String? = null) {
        controlsVisible = true
        topInfo.visibility = View.VISIBLE
        bottomInfo.visibility = View.VISIBLE
        if (message != null) {
            centerStatus.visibility = View.VISIBLE
            centerStatus.text = message
        }
        refreshBottomText()
        scheduleHideControls()
    }

    private fun hideControls() {
        controlsVisible = false
        topInfo.visibility = View.GONE
        bottomInfo.visibility = View.GONE
        if (player?.playbackState == Player.STATE_READY) {
            centerStatus.visibility = View.GONE
        }
        handler.removeCallbacks(hideControlsRunnable)
    }

    private fun scheduleHideControls() {
        handler.removeCallbacks(hideControlsRunnable)
        handler.postDelayed(hideControlsRunnable, 4200)
    }

    private fun refreshBottomText() {
        bottomInfo.text = controlsText()
        topInfo.text = "$title  •  EP $episode/$totalEpisodes  •  $quality"
    }

    private fun controlsText(): String {
        val state = if (player?.isPlaying == true) "PLAY" else "PAUSE"
        return "$state   OK Play/Pause   ←/→ Seek 10s   ↑ Controls   ↓ Episode   MENU Opsi   BACK Tutup/Keluar"
    }
}
