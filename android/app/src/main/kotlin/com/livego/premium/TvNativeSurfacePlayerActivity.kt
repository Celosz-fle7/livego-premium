package com.livego.premium

import android.app.Activity
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

class TvNativeSurfacePlayerActivity : Activity() {
    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var overlay: LinearLayout
    private lateinit var titleText: TextView
    private lateinit var infoText: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var controlsText: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var overlayVisible = true
    private var lastBackMs = 0L

    private val progressTask = object : Runnable {
        override fun run() {
            updateOverlay()
            handler.postDelayed(this, 500)
        }
    }

    private val hideTask = Runnable {
        setOverlayVisible(false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(Color.BLACK))
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE

        val url = intent.getStringExtra("url").orEmpty()
        if (url.isBlank()) {
            finish()
            return
        }

        val title = intent.getStringExtra("title").orEmpty().ifBlank { "LiveGO Player" }
        val episode = intent.getIntExtra("episode", 1)
        val total = intent.getIntExtra("totalEpisodes", 0)
        val headerKeys = intent.getStringArrayListExtra("headerKeys") ?: arrayListOf()
        val headerValues = intent.getStringArrayListExtra("headerValues") ?: arrayListOf()
        val headers = linkedMapOf<String, String>()
        for (i in 0 until min(headerKeys.size, headerValues.size)) {
            val key = headerKeys[i]
            val value = headerValues[i]
            if (key.isNotBlank() && value.isNotBlank()) headers[key] = value
        }

        val root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)

        playerView = PlayerView(this)
        playerView.setBackgroundColor(Color.BLACK)
        playerView.useController = false
        playerView.keepScreenOn = true
        root.addView(
            playerView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        overlay = LinearLayout(this)
        overlay.orientation = LinearLayout.VERTICAL
        overlay.setPadding(34, 24, 34, 24)
        overlay.setBackgroundColor(0xCC06111F.toInt())

        titleText = TextView(this)
        titleText.setTextColor(Color.WHITE)
        titleText.textSize = 22f
        titleText.typeface = android.graphics.Typeface.DEFAULT_BOLD
        titleText.maxLines = 1
        titleText.text = title
        overlay.addView(titleText)

        infoText = TextView(this)
        infoText.setTextColor(0xFFE6F7FF.toInt())
        infoText.textSize = 13f
        infoText.typeface = android.graphics.Typeface.DEFAULT_BOLD
        infoText.text = episodeLabel(episode, total)
        overlay.addView(infoText)

        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal)
        progressBar.max = 1000
        val progressParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            16,
        )
        progressParams.setMargins(0, 18, 0, 14)
        overlay.addView(progressBar, progressParams)

        controlsText = TextView(this)
        controlsText.setTextColor(Color.WHITE)
        controlsText.textSize = 13f
        controlsText.typeface = android.graphics.Typeface.DEFAULT_BOLD
        controlsText.gravity = Gravity.CENTER
        controlsText.text = "OK Play/Pause   ←/→ Seek 10s   BACK Hide/Exit"
        overlay.addView(controlsText)

        val overlayParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        )
        overlayParams.gravity = Gravity.BOTTOM
        overlayParams.leftMargin = 42
        overlayParams.rightMargin = 42
        overlayParams.bottomMargin = 36
        root.addView(overlay, overlayParams)

        setContentView(root)

        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(headers)
            .setUserAgent(headers["User-Agent"] ?: "LiveGO Premium TV")

        val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory)

        val exo = ExoPlayer.Builder(this)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()

        player = exo
        playerView.player = exo
        exo.repeatMode = Player.REPEAT_MODE_OFF
        exo.setMediaItem(MediaItem.fromUri(Uri.parse(url)))
        exo.prepare()
        exo.playWhenReady = true

        showOverlayAndScheduleHide()
        handler.post(progressTask)
    }

    private fun episodeLabel(episode: Int, total: Int): String {
        return if (total > 1 && total < 999) "EP $episode / $total" else "EP $episode"
    }

    private fun showOverlayAndScheduleHide() {
        setOverlayVisible(true)
        handler.removeCallbacks(hideTask)
        handler.postDelayed(hideTask, 5000)
    }

    private fun setOverlayVisible(visible: Boolean) {
        overlayVisible = visible
        if (::overlay.isInitialized) overlay.visibility = if (visible) View.VISIBLE else View.GONE
    }

    private fun fmt(ms: Long): String {
        val safe = max(0L, ms)
        val totalSeconds = safe / 1000L
        val h = totalSeconds / 3600L
        val m = (totalSeconds % 3600L) / 60L
        val s = totalSeconds % 60L
        return if (h > 0) {
            String.format(Locale.US, "%d:%02d:%02d", h, m, s)
        } else {
            String.format(Locale.US, "%02d:%02d", m, s)
        }
    }

    private fun updateOverlay() {
        val p = player ?: return
        val duration = if (p.duration > 0) p.duration else 0L
        val position = if (p.currentPosition > 0) p.currentPosition else 0L

        if (duration > 0) {
            progressBar.progress = ((position.toDouble() / duration.toDouble()) * 1000.0).toInt().coerceIn(0, 1000)
        } else {
            progressBar.progress = 0
        }

        val state = when (p.playbackState) {
            Player.STATE_BUFFERING -> "BUFFER"
            Player.STATE_READY -> if (p.isPlaying) "PLAY" else "PAUSE"
            Player.STATE_ENDED -> "ENDED"
            Player.STATE_IDLE -> "IDLE"
            else -> "PLAYER"
        }
        infoText.text = "${fmt(position)} / ${fmt(duration)}   $state"
    }

    private fun togglePlay() {
        val p = player ?: return
        if (p.isPlaying) p.pause() else p.play()
        showOverlayAndScheduleHide()
        updateOverlay()
    }

    private fun seekBy(deltaMs: Long) {
        val p = player ?: return
        val duration = if (p.duration > 0) p.duration else Long.MAX_VALUE
        val next = (p.currentPosition + deltaMs).coerceIn(0L, duration)
        p.seekTo(next)
        showOverlayAndScheduleHide()
        updateOverlay()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return true

        when (event.keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                val now = System.currentTimeMillis()
                if (now - lastBackMs < 350L) return true
                lastBackMs = now

                if (overlayVisible) {
                    setOverlayVisible(false)
                } else {
                    finish()
                }
                return true
            }

            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_SPACE -> {
                if (event.repeatCount == 0) togglePlay()
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

            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_MENU -> {
                showOverlayAndScheduleHide()
                return true
            }
        }

        return super.dispatchKeyEvent(event)
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
}
