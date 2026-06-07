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
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
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
    private enum class PanelMode { DOCK, EPISODE, QUALITY, SUBTITLE, OPTIONS }

    private data class QualityRow(val label: String, val url: String)
    private data class SubtitleRow(val label: String, val url: String, val format: String)

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var overlay: LinearLayout
    private lateinit var titleText: TextView
    private lateinit var infoText: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var dockRow: LinearLayout
    private lateinit var panelBox: LinearLayout
    private lateinit var hintText: TextView

    private val dockButtons = ArrayList<TextView>()
    private val panelRows = ArrayList<TextView>()
    private val handler = Handler(Looper.getMainLooper())

    private var title = "LiveGO Player"
    private var episode = 1
    private var totalEpisodes = 0
    private var selectedControl = 1
    private var qualityCursor = 0
    private var subtitleCursor = 0
    private var optionCursor = 0
    private var episodeCursor = 1
    private var speedIndex = 1
    private var overlayVisible = true
    private var fitCover = false
    private var muted = false
    private var panelMode = PanelMode.DOCK
    private var lastBackMs = 0L
    private var lastMoveMs = 0L
    private var currentUrl = ""

    private val speeds = floatArrayOf(0.75f, 1.0f, 1.25f, 1.5f, 2.0f)
    private val qualities = ArrayList<QualityRow>()
    private val subtitles = ArrayList<SubtitleRow>()
    private val headers = linkedMapOf<String, String>()

    private val progressTask = object : Runnable {
        override fun run() {
            updateOverlay()
            handler.postDelayed(this, 500)
        }
    }

    private val hideTask = Runnable { hideOverlayIfDock() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        blackWindow()

        currentUrl = intent.getStringExtra("url").orEmpty()
        if (currentUrl.isBlank()) {
            finish()
            return
        }

        title = intent.getStringExtra("title").orEmpty().ifBlank { "LiveGO Player" }
        episode = intent.getIntExtra("episode", 1)
        totalEpisodes = intent.getIntExtra("totalEpisodes", 0)
        episodeCursor = episode

        readHeaders()
        readQualities()
        readSubtitles()

        setContentView(buildRoot())
        createPlayer(currentUrl, keepPositionMs = 0L, playWhenReady = true)

        showOverlayAndScheduleHide()
        handler.post(progressTask)
        updateAllUi()
    }

    private fun readHeaders() {
        val keys = intent.getStringArrayListExtra("headerKeys") ?: arrayListOf()
        val values = intent.getStringArrayListExtra("headerValues") ?: arrayListOf()
        for (i in 0 until min(keys.size, values.size)) {
            val k = keys[i]
            val v = values[i]
            if (k.isNotBlank() && v.isNotBlank()) headers[k] = v
        }
    }

    private fun readQualities() {
        val labels = intent.getStringArrayListExtra("qualityLabels") ?: arrayListOf()
        val urls = intent.getStringArrayListExtra("qualityUrls") ?: arrayListOf()
        qualities.clear()
        qualities.add(QualityRow("Auto", currentUrl))
        for (i in 0 until min(labels.size, urls.size)) {
            val label = labels[i].ifBlank { "Quality ${i + 1}" }
            val url = urls[i]
            if (url.isNotBlank() && qualities.none { it.url == url }) {
                qualities.add(QualityRow(label, url))
            }
        }
        qualityCursor = qualities.indexOfFirst { it.url == currentUrl }.coerceAtLeast(0)
    }

    private fun readSubtitles() {
        val labels = intent.getStringArrayListExtra("subtitleLabels") ?: arrayListOf()
        val urls = intent.getStringArrayListExtra("subtitleUrls") ?: arrayListOf()
        val formats = intent.getStringArrayListExtra("subtitleFormats") ?: arrayListOf()
        subtitles.clear()
        subtitles.add(SubtitleRow("OFF", "", ""))
        for (i in 0 until min(labels.size, urls.size)) {
            val label = labels[i].ifBlank { "Subtitle ${i + 1}" }
            val url = urls[i]
            val format = formats.getOrNull(i) ?: ""
            if (url.isNotBlank()) subtitles.add(SubtitleRow(label, url, format))
        }
        subtitleCursor = 0
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

        panelBox = LinearLayout(this)
        panelBox.orientation = LinearLayout.VERTICAL
        panelBox.visibility = View.GONE
        val panelParams = LinearLayout.LayoutParams(-1, -2)
        panelParams.setMargins(0, 14, 0, 0)
        overlay.addView(panelBox, panelParams)

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

    private fun createPlayer(url: String, keepPositionMs: Long, playWhenReady: Boolean) {
        val old = player
        old?.pause()

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
        exo.setMediaItem(buildMediaItem(url))
        exo.prepare()
        if (keepPositionMs > 0) exo.seekTo(keepPositionMs)
        exo.playWhenReady = playWhenReady
        exo.setPlaybackSpeed(speeds[speedIndex])
        exo.volume = if (muted) 0f else 1f

        old?.release()
        currentUrl = url
    }

    private fun buildMediaItem(url: String): MediaItem {
        val builder = MediaItem.Builder().setUri(Uri.parse(url))
        val sub = subtitles.getOrNull(subtitleCursor)
        if (sub != null && sub.url.isNotBlank()) {
            val mime = when (sub.format.lowercase(Locale.US)) {
                "vtt", "webvtt" -> MimeTypes.TEXT_VTT
                "srt", "subrip" -> MimeTypes.APPLICATION_SUBRIP
                else -> MimeTypes.TEXT_VTT
            }
            val config = MediaItem.SubtitleConfiguration.Builder(Uri.parse(sub.url))
                .setMimeType(mime)
                .setLanguage(sub.label.take(8))
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
            builder.setSubtitleConfigurations(listOf(config))
        }
        return builder.build()
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
        if (panelMode == PanelMode.DOCK) {
            handler.removeCallbacks(hideTask)
            handler.postDelayed(hideTask, 5000)
        }
    }

    private fun hideOverlayIfDock() {
        if (panelMode == PanelMode.DOCK) setOverlayVisible(false)
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

    private fun updateAllUi() {
        updateDock()
        updatePanel()
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
            b.background = if (i == selectedControl && panelMode == PanelMode.DOCK) selectedBg() else roundedBg(0x55203245, 18, 0x334E6B7D)
            b.setTextColor(if (i == selectedControl && panelMode == PanelMode.DOCK) Color.WHITE else 0xFFD8E4F0.toInt())
        }
    }

    private fun updatePanel() {
        panelBox.removeAllViews()
        panelRows.clear()

        if (panelMode == PanelMode.DOCK) {
            panelBox.visibility = View.GONE
            return
        }

        panelBox.visibility = View.VISIBLE
        when (panelMode) {
            PanelMode.EPISODE -> buildRows(
                title = "Episode",
                rows = episodeRows(),
                cursor = episodeCursorForRows(),
            )
            PanelMode.QUALITY -> buildRows(
                title = "Quality",
                rows = qualities.map { it.label },
                cursor = qualityCursor.coerceIn(0, max(0, qualities.size - 1)),
            )
            PanelMode.SUBTITLE -> buildRows(
                title = "Subtitle",
                rows = subtitles.map { it.label },
                cursor = subtitleCursor.coerceIn(0, max(0, subtitles.size - 1)),
            )
            PanelMode.OPTIONS -> buildRows(
                title = "Options",
                rows = optionRows(),
                cursor = optionCursor.coerceIn(0, 5),
            )
            PanelMode.DOCK -> Unit
        }
    }

    private fun buildRows(title: String, rows: List<String>, cursor: Int) {
        val titleView = label(title, 16f, Color.WHITE, true)
        titleView.gravity = Gravity.CENTER
        panelBox.addView(titleView, LinearLayout.LayoutParams(-1, -2))

        val safeRows = rows.ifEmpty { listOf("Tidak tersedia") }
        safeRows.take(11).forEachIndexed { index, row ->
            val v = label(row, 13f, Color.WHITE, true)
            v.gravity = Gravity.CENTER_VERTICAL
            v.setPadding(18, 10, 18, 10)
            v.background = if (index == cursor) selectedBg() else roundedBg(0x44203245, 16, 0x334E6B7D)
            val lp = LinearLayout.LayoutParams(-1, 48)
            lp.setMargins(0, 7, 0, 0)
            panelBox.addView(v, lp)
            panelRows.add(v)
        }
    }

    private fun episodeRows(): List<String> {
        if (totalEpisodes <= 1 || totalEpisodes >= 999) return listOf("Episode $episode", "Episode list penuh butuh resolver bridge")
        val start = (episodeCursor - 5).coerceIn(1, totalEpisodes)
        val end = (start + 10).coerceAtMost(totalEpisodes)
        val fixedStart = (end - 10).coerceAtLeast(1)
        return (fixedStart..end).map { ep -> if (ep == episode) "Episode $ep  •  Now" else "Episode $ep" }
    }

    private fun episodeCursorForRows(): Int {
        if (totalEpisodes <= 1 || totalEpisodes >= 999) return 0
        val start = (episodeCursor - 5).coerceIn(1, totalEpisodes)
        val end = (start + 10).coerceAtMost(totalEpisodes)
        val fixedStart = (end - 10).coerceAtLeast(1)
        return (episodeCursor - fixedStart).coerceIn(0, 10)
    }

    private fun optionRows(): List<String> {
        val speed = speeds[speedIndex]
        val speedText = if (speed == speed.toInt().toFloat()) "${speed.toInt()}x" else "${speed}x"
        return listOf(
            "Speed  $speedText",
            "Layar  ${if (fitCover) "Cover" else "Fit"}",
            "Volume  ${if (muted) "Mute" else "Normal"}",
            "Quality  ${qualities.getOrNull(qualityCursor)?.label ?: "Auto"}",
            "Subtitle  ${subtitles.getOrNull(subtitleCursor)?.label ?: "OFF"}",
            "Back to controls"
        )
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
        updateAllUi()
    }

    private fun movePanel(delta: Int) {
        if (!allowMove()) return
        when (panelMode) {
            PanelMode.EPISODE -> {
                val total = if (totalEpisodes > 1 && totalEpisodes < 999) totalEpisodes else episode
                episodeCursor = (episodeCursor + delta).coerceIn(1, total)
            }
            PanelMode.QUALITY -> qualityCursor = (qualityCursor + delta).coerceIn(0, max(0, qualities.size - 1))
            PanelMode.SUBTITLE -> subtitleCursor = (subtitleCursor + delta).coerceIn(0, max(0, subtitles.size - 1))
            PanelMode.OPTIONS -> optionCursor = (optionCursor + delta).coerceIn(0, 5)
            PanelMode.DOCK -> Unit
        }
        updatePanel()
        showOverlayAndScheduleHide()
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
        updateAllUi()
    }

    private fun toggleFit() {
        fitCover = !fitCover
        playerView.resizeMode = if (fitCover) AspectRatioFrameLayout.RESIZE_MODE_ZOOM else AspectRatioFrameLayout.RESIZE_MODE_FIT
        showOverlayAndScheduleHide()
        updateAllUi()
    }

    private fun toggleMute() {
        muted = !muted
        player?.volume = if (muted) 0f else 1f
        showOverlayAndScheduleHide()
        updateAllUi()
    }

    private fun showPanel(mode: PanelMode) {
        panelMode = mode
        handler.removeCallbacks(hideTask)
        setOverlayVisible(true)
        updateAllUi()
    }

    private fun applyQuality() {
        val row = qualities.getOrNull(qualityCursor) ?: return
        val p = player
        val position = p?.currentPosition ?: 0L
        val playing = p?.isPlaying ?: true
        createPlayer(row.url, keepPositionMs = position, playWhenReady = playing)
        panelMode = PanelMode.DOCK
        showOverlayAndScheduleHide()
        updateAllUi()
    }

    private fun applySubtitle() {
        val p = player
        val position = p?.currentPosition ?: 0L
        val playing = p?.isPlaying ?: true
        createPlayer(currentUrl, keepPositionMs = position, playWhenReady = playing)
        panelMode = PanelMode.DOCK
        showOverlayAndScheduleHide()
        updateAllUi()
    }

    private fun activateControl() {
        when (selectedControl) {
            0 -> hintText.text = "Prev episode butuh resolver bridge Flutter"
            1 -> togglePlay()
            2 -> hintText.text = "Next episode butuh resolver bridge Flutter"
            3 -> showPanel(PanelMode.EPISODE)
            4 -> showPanel(PanelMode.QUALITY)
            5 -> showPanel(PanelMode.SUBTITLE)
            6 -> changeSpeed()
            7 -> showPanel(PanelMode.OPTIONS)
        }
        showOverlayAndScheduleHide()
    }

    private fun activatePanel() {
        when (panelMode) {
            PanelMode.EPISODE -> {
                hintText.text = if (episodeCursor == episode) {
                    "Episode $episode sedang diputar"
                } else {
                    "Episode reload butuh resolver bridge Flutter"
                }
                panelMode = PanelMode.DOCK
            }
            PanelMode.QUALITY -> applyQuality()
            PanelMode.SUBTITLE -> applySubtitle()
            PanelMode.OPTIONS -> activateOption()
            PanelMode.DOCK -> activateControl()
        }
        updateAllUi()
    }

    private fun activateOption() {
        when (optionCursor) {
            0 -> changeSpeed()
            1 -> toggleFit()
            2 -> toggleMute()
            3 -> showPanel(PanelMode.QUALITY)
            4 -> showPanel(PanelMode.SUBTITLE)
            5 -> panelMode = PanelMode.DOCK
        }
    }

    private fun handleBack() {
        val now = System.currentTimeMillis()
        if (now - lastBackMs < 350L) return
        lastBackMs = now

        if (panelMode != PanelMode.DOCK) {
            panelMode = PanelMode.DOCK
            showOverlayAndScheduleHide()
            updateAllUi()
            return
        }

        if (overlayVisible) {
            setOverlayVisible(false)
        } else {
            finish()
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return true

        when (event.keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                handleBack()
                return true
            }

            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_SPACE -> {
                if (event.repeatCount == 0) {
                    if (!overlayVisible) togglePlay()
                    else if (panelMode == PanelMode.DOCK) activateControl()
                    else activatePanel()
                }
                return true
            }

            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (!overlayVisible) seekBy(-10_000L)
                else if (panelMode == PanelMode.DOCK) moveControl(-1)
                else {
                    panelMode = PanelMode.DOCK
                    updateAllUi()
                }
                return true
            }

            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (!overlayVisible) seekBy(10_000L)
                else if (panelMode == PanelMode.DOCK) moveControl(1)
                else activatePanel()
                return true
            }

            KeyEvent.KEYCODE_DPAD_UP -> {
                if (!overlayVisible) showOverlayAndScheduleHide()
                else if (panelMode == PanelMode.DOCK) showPanel(PanelMode.OPTIONS)
                else movePanel(-1)
                return true
            }

            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (!overlayVisible) showPanel(PanelMode.EPISODE)
                else if (panelMode == PanelMode.DOCK) showPanel(PanelMode.EPISODE)
                else movePanel(1)
                return true
            }

            KeyEvent.KEYCODE_MENU -> {
                showPanel(PanelMode.OPTIONS)
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
