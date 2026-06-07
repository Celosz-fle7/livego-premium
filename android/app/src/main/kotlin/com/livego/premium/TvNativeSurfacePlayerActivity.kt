package com.livego.premium

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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
import androidx.media3.ui.AspectRatioFrameLayout
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
    private lateinit var dockRow: LinearLayout
    private lateinit var hintText: TextView
    private val dockButtons = ArrayList<TextView>()
    private val handler = Handler(Looper.getMainLooper())

    private var title = "LiveGO Player"
    private var episode = 1
    private var totalEpisodes = 0
    private var selectedControl = 1
    private var speedIndex = 1
    private var overlayVisible = true
    private var fitCover = false
    private var lastBackMs = 0L
    private var lastMoveMs = 0L
    private val speeds = floatArrayOf(0.75f, 1.0f, 1.25f, 1.5f, 2.0f)

    private val progressTask = object : Runnable {
        override fun run() {
            updateOverlay()
            handler.postDelayed(this, 500)
        }
    }

    private val hideTask = Runnable { setOverlayVisible(false) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        blackWindow()

        val url = intent.getStringExtra("url").orEmpty()
        if (url.isBlank()) {
            finish()
            return
        }

        title = intent.getStringExtra("title").orEmpty().ifBlank { "LiveGO Player" }
        episode = intent.getIntExtra("episode", 1)
        totalEpisodes = intent.getIntExtra("totalEpisodes", 0)

        val headerKeys = intent.getStringArrayListExtra("headerKeys") ?: arrayListOf()
        val headerValues = intent.getStringArrayListExtra("headerValues") ?: arrayListOf()
        val headers = linkedMapOf<String, String>()
        for (i in 0 until min(headerKeys.size, headerValues.size)) {
            val k = headerKeys[i]
            val v = headerValues[i]
            if (k.isNotBlank() && v.isNotBlank()) headers[k] = v
        }

        setContentView(buildRoot())

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
        updateDock()
    }

    private fun blackWindow() {
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
    }

    private fun buildRoot(): FrameLayout {
        val root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)

        playerView = PlayerView(this)
        playerView.setBackgroundColor(Color.BLACK)
        playerView.useController = false
        playerView.keepScreenOn = true
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        root.addView(playerView, FrameLayout.LayoutParams(-1, -1))

        overlay = LinearLayout(this)
        overlay.orientation = LinearLayout.VERTICAL
        overlay.setPadding(34, 24, 34, 24)
        overlay.background = roundedBg(0xDD06111F.toInt(), 26, 0x662FE7FF)

        titleText = label(title, 22f, Color.WHITE, true)
        overlay.addView(titleText)

        infoText = label(episodeLabel(), 13f, 0xFFE6F7FF.toInt(), true)
        overlay.addView(infoText)

        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal)
        progressBar.max = 1000
        val progressParams = LinearLayout.LayoutParams(-1, 16)
        progressParams.setMargins(0, 18, 0, 14)
        overlay.addView(progressBar, progressParams)

        dockRow = LinearLayout(this)
        dockRow.orientation = LinearLayout.HORIZONTAL
        dockRow.gravity = Gravity.CENTER
        overlay.addView(dockRow, LinearLayout.LayoutParams(-1, 70))

        repeat(8) { index ->
            val b = label("", 12f, Color.WHITE, true)
            b.gravity = Gravity.CENTER
            b.maxLines = 2
            val lp = LinearLayout.LayoutParams(0, -1, 1f)
            if (index > 0) lp.leftMargin = 10
            dockRow.addView(b, lp)
            dockButtons.add(b)
        }

        hintText = label("←/→ pilih kontrol • OK aktifkan • BACK sembunyi/keluar", 12f, 0xFFB8C5D6.toInt(), true)
        hintText.gravity = Gravity.CENTER
        val hintParams = LinearLayout.LayoutParams(-1, -2)
        hintParams.setMargins(0, 12, 0, 0)
        overlay.addView(hintText, hintParams)

        val params = FrameLayout.LayoutParams(-1, -2)
        params.gravity = Gravity.BOTTOM
        params.leftMargin = 42
        params.rightMargin = 42
        params.bottomMargin = 36
        root.addView(overlay, params)
        return root
    }

    private fun label(text: String, sp: Float, color: Int, bold: Boolean): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = sp
            setTextColor(color)
            typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            includeFontPadding = true
            maxLines = 1
        }
    }

    private fun roundedBg(color: Int, radius: Int, stroke: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = radius.toFloat()
            setStroke(1, stroke)
        }
    }

    private fun selectedBg(): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(0xFF34C8FF.toInt(), 0xFF7C5CFF.toInt())
        ).apply {
            cornerRadius = 18f
            setStroke(2, Color.WHITE)
        }
    }

    private fun episodeLabel(): String {
        return if (totalEpisodes > 1 && totalEpisodes < 999) "EP $episode / $totalEpisodes" else "EP $episode"
    }

    private fun fmt(ms: Long): String {
        val safe = max(0L, ms)
        val totalSeconds = safe / 1000L
        val h = totalSeconds / 3600L
        val m = (totalSeconds % 3600L) / 60L
        val s = totalSeconds % 60L
        return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s)
        else String.format(Locale.US, "%02d:%02d", m, s)
    }

    private fun showOverlayAndScheduleHide() {
        setOverlayVisible(true)
        handler.removeCallbacks(hideTask)
        handler.postDelayed(hideTask, 5000)
    }

    private fun setOverlayVisible(visible: Boolean) {
        overlayVisible = visible
        overlay.visibility = if (visible) View.VISIBLE else View.GONE
    }

    private fun updateOverlay() {
        val p = player ?: return
        val duration = if (p.duration > 0) p.duration else 0L
        val position = if (p.currentPosition > 0) p.currentPosition else 0L
        progressBar.progress = if (duration > 0) {
            ((position.toDouble() / duration.toDouble()) * 1000.0).toInt().coerceIn(0, 1000)
        } else 0

        val state = when (p.playbackState) {
            Player.STATE_BUFFERING -> "BUFFER"
            Player.STATE_READY -> if (p.isPlaying) "PLAY" else "PAUSE"
            Player.STATE_ENDED -> "ENDED"
            Player.STATE_IDLE -> "IDLE"
            else -> "PLAYER"
        }
        infoText.text = "${episodeLabel()}   ${fmt(position)} / ${fmt(duration)}   $state"
        updateDock()
    }

    private fun updateDock() {
        val p = player
        val speed = speeds[speedIndex]
        val speedText = if (speed == speed.toInt().toFloat()) "${speed.toInt()}x" else "${speed}x"
        val labels = listOf(
            "⏮\nPrev",
            if (p?.isPlaying == true) "⏸\nPause" else "▶\nPlay",
            "⏭\nNext",
            "☰\nEpisode",
            "HD\nQuality",
            "▤\nSubtitle",
            "⏱\nSpeed $speedText",
            "•••\nMore"
        )
        for (i in dockButtons.indices) {
            val b = dockButtons[i]
            b.text = labels[i]
            b.background = if (i == selectedControl) selectedBg() else roundedBg(0x55203245, 18, 0x334E6B7D)
            b.setTextColor(if (i == selectedControl) Color.WHITE else 0xFFD8E4F0.toInt())
        }
    }

    private fun allowMove(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastMoveMs < 95L) return false
        lastMoveMs = now
        return true
    }

    private fun moveControl(delta: Int) {
        if (!allowMove()) return
        selectedControl = (selectedControl + delta).coerceIn(0, 7)
        showOverlayAndScheduleHide()
        updateDock()
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

    private fun changeSpeed() {
        speedIndex = (speedIndex + 1) % speeds.size
        player?.setPlaybackSpeed(speeds[speedIndex])
        showOverlayAndScheduleHide()
        updateDock()
    }

    private fun toggleFit() {
        fitCover = !fitCover
        playerView.resizeMode = if (fitCover) AspectRatioFrameLayout.RESIZE_MODE_ZOOM else AspectRatioFrameLayout.RESIZE_MODE_FIT
        hintText.text = if (fitCover) "Layar Cover" else "Layar Fit"
        showOverlayAndScheduleHide()
    }

    private fun activateControl() {
        when (selectedControl) {
            0 -> hintText.text = "Prev episode native batch berikutnya"
            1 -> togglePlay()
            2 -> hintText.text = "Next episode native batch berikutnya"
            3 -> hintText.text = "Episode panel native batch berikutnya"
            4 -> hintText.text = "Quality panel native batch berikutnya"
            5 -> hintText.text = "Subtitle panel native batch berikutnya"
            6 -> changeSpeed()
            7 -> toggleFit()
        }
        showOverlayAndScheduleHide()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return true
        when (event.keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                val now = System.currentTimeMillis()
                if (now - lastBackMs < 350L) return true
                lastBackMs = now
                if (overlayVisible) setOverlayVisible(false) else finish()
                return true
            }
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_SPACE -> {
                if (event.repeatCount == 0) {
                    if (overlayVisible) activateControl() else togglePlay()
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (overlayVisible) moveControl(-1) else seekBy(-10_000L)
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (overlayVisible) moveControl(1) else seekBy(10_000L)
                return true
            }
            KeyEvent.KEYCODE_MEDIA_REWIND -> {
                seekBy(-10_000L)
                return true
            }
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
