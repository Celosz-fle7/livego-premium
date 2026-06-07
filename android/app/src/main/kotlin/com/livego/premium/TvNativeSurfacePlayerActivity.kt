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
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
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
    private enum class Mode { CLEAN, DOCK, EPISODE, QUALITY, SUBTITLE, OPTIONS }

    private data class QualityRow(val label: String, val url: String)
    private data class SubtitleRow(val label: String, val url: String, val format: String)

    private var player: ExoPlayer? = null
    private lateinit var root: FrameLayout
    private lateinit var playerView: PlayerView
    private lateinit var topInfo: LinearLayout
    private lateinit var bottomDock: LinearLayout
    private lateinit var panelShell: LinearLayout
    private lateinit var titleText: TextView
    private lateinit var descText: TextView
    private lateinit var metaText: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var leftTime: TextView
    private lateinit var rightTime: TextView
    private lateinit var controlRow: LinearLayout
    private lateinit var hintText: TextView
    private lateinit var panelTitle: TextView
    private lateinit var panelBody: LinearLayout

    private val controlButtons = ArrayList<TextView>()
    private val handler = Handler(Looper.getMainLooper())

    private var title = "LiveGO Player"
    private var description = ""
    private var source = ""
    private var category = ""
    private var currentUrl = ""
    private var episode = 1
    private var totalEpisodes = 0
    private var selectedControl = 1
    private var episodeCursor = 1
    private var qualityCursor = 0
    private var subtitleCursor = 0
    private var optionCursor = 0
    private var speedIndex = 1
    private var fitCover = false
    private var muted = false
    private var mode = Mode.DOCK
    private var lastBackMs = 0L
    private var lastMoveMs = 0L

    private val speeds = floatArrayOf(0.75f, 1.0f, 1.25f, 1.5f, 2.0f)
    private val qualities = ArrayList<QualityRow>()
    private val subtitles = ArrayList<SubtitleRow>()
    private val headers = linkedMapOf<String, String>()

    private val tick = object : Runnable {
        override fun run() {
            updateProgress()
            handler.postDelayed(this, 500)
        }
    }

    private val hideDockTask = Runnable {
        if (mode == Mode.DOCK) setMode(Mode.CLEAN)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        blackWindow()

        currentUrl = intent.getStringExtra("url").orEmpty()
        if (currentUrl.isBlank()) {
            finish()
            return
        }

        title = intent.getStringExtra("title").orEmpty().ifBlank { "LiveGO Player" }
        description = intent.getStringExtra("description").orEmpty()
        source = intent.getStringExtra("source").orEmpty()
        category = intent.getStringExtra("category").orEmpty()
        episode = intent.getIntExtra("episode", 1)
        totalEpisodes = intent.getIntExtra("totalEpisodes", 0)
        episodeCursor = episode

        readHeaders()
        readQualities()
        readSubtitles()

        root = buildRoot()
        setContentView(root)
        createPlayer(currentUrl, keepPositionMs = 0L, playWhenReady = true)

        setMode(Mode.DOCK)
        handler.post(tick)
    }

    private fun readHeaders() {
        val keys = intent.getStringArrayListExtra("headerKeys") ?: arrayListOf()
        val values = intent.getStringArrayListExtra("headerValues") ?: arrayListOf()
        for (i in 0 until min(keys.size, values.size)) {
            val key = keys[i]
            val value = values[i]
            if (key.isNotBlank() && value.isNotBlank()) headers[key] = value
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
        val frame = FrameLayout(this)
        frame.setBackgroundColor(Color.BLACK)

        playerView = PlayerView(this)
        playerView.setBackgroundColor(Color.BLACK)
        playerView.useController = false
        playerView.keepScreenOn = true
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        frame.addView(playerView, FrameLayout.LayoutParams(-1, -1))

        topInfo = LinearLayout(this)
        topInfo.orientation = LinearLayout.VERTICAL
        topInfo.setPadding(dp(42), dp(28), dp(42), dp(18))
        topInfo.background = verticalGradient(0x99000000.toInt(), 0x22000000)
        titleText = label(title, 24f, Color.WHITE, true)
        titleText.maxLines = 1
        topInfo.addView(titleText, LinearLayout.LayoutParams(-1, -2))
        descText = label(description.ifBlank { " " }, 14f, 0xFFE5E7EB.toInt(), false)
        descText.maxLines = 2
        val descLp = LinearLayout.LayoutParams(-1, -2)
        descLp.setMargins(0, dp(8), 0, dp(10))
        topInfo.addView(descText, descLp)
        metaText = label(metaLine(), 12f, 0xFFD7E8F6.toInt(), true)
        topInfo.addView(metaText, LinearLayout.LayoutParams(-1, -2))
        val topParams = FrameLayout.LayoutParams(-1, -2)
        topParams.gravity = Gravity.TOP
        frame.addView(topInfo, topParams)

        bottomDock = LinearLayout(this)
        bottomDock.orientation = LinearLayout.VERTICAL
        bottomDock.setPadding(dp(28), dp(18), dp(28), dp(18))
        bottomDock.background = roundedBg(0xDD071321.toInt(), dp(24), 0x772A9FD6)

        val timeRow = LinearLayout(this)
        timeRow.orientation = LinearLayout.HORIZONTAL
        timeRow.gravity = Gravity.CENTER_VERTICAL
        leftTime = label("00:00", 17f, Color.WHITE, true)
        rightTime = label("00:00", 17f, Color.WHITE, true)
        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal)
        progressBar.max = 1000
        val timeLeftParams = LinearLayout.LayoutParams(dp(82), -2)
        timeRow.addView(leftTime, timeLeftParams)
        val progressParams = LinearLayout.LayoutParams(0, dp(12), 1f)
        progressParams.setMargins(dp(10), 0, dp(10), 0)
        timeRow.addView(progressBar, progressParams)
        timeRow.addView(rightTime, LinearLayout.LayoutParams(dp(82), -2))
        bottomDock.addView(timeRow, LinearLayout.LayoutParams(-1, -2))

        controlRow = LinearLayout(this)
        controlRow.orientation = LinearLayout.HORIZONTAL
        controlRow.gravity = Gravity.CENTER
        val controlLp = LinearLayout.LayoutParams(-1, dp(70))
        controlLp.setMargins(0, dp(18), 0, 0)
        bottomDock.addView(controlRow, controlLp)

        repeat(9) { index ->
            val button = label("", 13f, Color.WHITE, true)
            button.gravity = Gravity.CENTER
            button.maxLines = 2
            val lp = LinearLayout.LayoutParams(if (index == 4) dp(128) else dp(76), -1)
            if (index > 0) lp.leftMargin = dp(8)
            controlRow.addView(button, lp)
            controlButtons.add(button)
        }

        hintText = label("←/→ pilih kontrol • OK aktifkan • DOWN episode • UP/More opsi • BACK hide/exit", 12f, 0xFFC9D7E3.toInt(), true)
        hintText.gravity = Gravity.CENTER
        val hintLp = LinearLayout.LayoutParams(-1, -2)
        hintLp.setMargins(0, dp(12), 0, 0)
        bottomDock.addView(hintText, hintLp)

        val dockParams = FrameLayout.LayoutParams(-1, -2)
        dockParams.gravity = Gravity.BOTTOM
        dockParams.leftMargin = dp(38)
        dockParams.rightMargin = dp(38)
        dockParams.bottomMargin = dp(32)
        frame.addView(bottomDock, dockParams)

        panelShell = LinearLayout(this)
        panelShell.orientation = LinearLayout.VERTICAL
        panelShell.setPadding(dp(20), dp(18), dp(20), dp(18))
        panelShell.background = roundedBg(0xEE071321.toInt(), dp(24), 0x7734C8FF)
        panelShell.visibility = View.GONE
        panelTitle = label("Panel", 22f, Color.WHITE, true)
        panelShell.addView(panelTitle, LinearLayout.LayoutParams(-1, -2))
        panelBody = LinearLayout(this)
        panelBody.orientation = LinearLayout.VERTICAL
        val bodyLp = LinearLayout.LayoutParams(-1, -1)
        bodyLp.setMargins(0, dp(16), 0, 0)
        panelShell.addView(panelBody, bodyLp)

        val panelParams = FrameLayout.LayoutParams(dp(460), -1)
        panelParams.gravity = Gravity.RIGHT
        panelParams.topMargin = dp(24)
        panelParams.rightMargin = dp(24)
        panelParams.bottomMargin = dp(24)
        frame.addView(panelShell, panelParams)

        return frame
    }

    private fun createPlayer(url: String, keepPositionMs: Long, playWhenReady: Boolean) {
        val old = player
        old?.pause()

        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(headers)
            .setUserAgent(headers["User-Agent"] ?: "LiveGO Premium TV")

        val exo = ExoPlayer.Builder(this)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSourceFactory))
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
                "srt", "subrip" -> MimeTypes.APPLICATION_SUBRIP
                "vtt", "webvtt" -> MimeTypes.TEXT_VTT
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

    private fun verticalGradient(top: Int, bottom: Int): GradientDrawable {
        return GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(top, bottom))
    }

    private fun selectedBg(): GradientDrawable {
        return GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(0xFF35CBFF.toInt(), 0xFF7D5CFF.toInt())).apply {
            cornerRadius = dp(16).toFloat()
            setStroke(dp(2), 0xFFEAFBFF.toInt())
        }
    }

    private fun normalBg(): GradientDrawable = roundedBg(0x55203245, dp(16), 0x334E6B7D)
    private fun activePanelBg(): GradientDrawable = selectedBg()
    private fun rowBg(focused: Boolean): GradientDrawable = if (focused) selectedBg() else roundedBg(0x55314257, dp(14), 0x334E6B7D)

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun metaLine(): String {
        val parts = ArrayList<String>()
        if (source.isNotBlank()) parts.add(source)
        if (category.isNotBlank()) parts.add(category)
        parts.add(episodeLabel())
        val quality = qualities.getOrNull(qualityCursor)?.label ?: "Auto"
        parts.add(quality)
        val sub = subtitles.getOrNull(subtitleCursor)?.label ?: "OFF"
        if (sub != "OFF") parts.add("Sub $sub")
        return parts.joinToString("  •  ")
    }

    private fun episodeLabel(): String = if (totalEpisodes > 1 && totalEpisodes < 999) "EP $episode / $totalEpisodes" else "EP $episode"

    private fun fmt(ms: Long): String {
        val safe = max(0L, ms)
        val total = safe / 1000L
        val h = total / 3600L
        val m = (total % 3600L) / 60L
        val s = total % 60L
        return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s) else String.format(Locale.US, "%02d:%02d", m, s)
    }

    private fun setMode(next: Mode) {
        mode = next
        handler.removeCallbacks(hideDockTask)
        when (next) {
            Mode.CLEAN -> {
                topInfo.visibility = View.GONE
                bottomDock.visibility = View.GONE
                panelShell.visibility = View.GONE
            }
            Mode.DOCK -> {
                topInfo.visibility = View.VISIBLE
                bottomDock.visibility = View.VISIBLE
                panelShell.visibility = View.GONE
                handler.postDelayed(hideDockTask, 5000)
            }
            Mode.EPISODE, Mode.QUALITY, Mode.SUBTITLE, Mode.OPTIONS -> {
                topInfo.visibility = View.GONE
                bottomDock.visibility = View.GONE
                panelShell.visibility = View.VISIBLE
                updatePanel()
            }
        }
        updateDock()
        updateProgress()
    }

    private fun updateProgress() {
        val p = player ?: return
        val duration = if (p.duration > 0) p.duration else 0L
        val position = if (p.currentPosition > 0) p.currentPosition else 0L
        progressBar.progress = if (duration > 0) ((position.toDouble() / duration.toDouble()) * 1000.0).toInt().coerceIn(0, 1000) else 0
        leftTime.text = fmt(position)
        rightTime.text = fmt(duration)
        metaText.text = metaLine()
        updateDock()
    }

    private fun updateDock() {
        if (controlButtons.size < 9) return
        val speed = speeds[speedIndex]
        val speedText = if (speed == speed.toInt().toFloat()) "${speed.toInt()}x" else "${speed}x"
        val labels = listOf(
            "⏮\nPrev",
            if (player?.isPlaying == true) "⏸\nPause" else "▶\nPlay",
            "⏭\nNext",
            "☰\nEpisode",
            qualities.getOrNull(qualityCursor)?.label ?: "Auto",
            "▣\nFit",
            "↻\n$speedText",
            "♡\nFav",
            "≡\nMore"
        )
        for (i in controlButtons.indices) {
            val b = controlButtons[i]
            b.text = labels[i]
            val selected = mode == Mode.DOCK && i == selectedControl
            b.background = if (selected) selectedBg() else normalBg()
            b.setTextColor(if (selected) Color.WHITE else 0xFFD8E4F0.toInt())
        }
    }

    private fun updatePanel() {
        panelBody.removeAllViews()
        when (mode) {
            Mode.EPISODE -> buildEpisodePanel()
            Mode.QUALITY -> buildChoicePanel("Kualitas Video", qualities.map { it.label }, qualityCursor)
            Mode.SUBTITLE -> buildChoicePanel("Subtitle", subtitles.map { it.label }, subtitleCursor)
            Mode.OPTIONS -> buildChoicePanel("Options", optionRows(), optionCursor)
            else -> Unit
        }
    }

    private fun buildEpisodePanel() {
        panelTitle.text = "Daftar Episode"
        val total = if (totalEpisodes > 1 && totalEpisodes < 999) totalEpisodes else max(episode, 1)
        val chip = label("$total Ep", 13f, 0xFFE9F8FF.toInt(), true)
        chip.gravity = Gravity.CENTER
        chip.background = roundedBg(0x55314257, dp(14), 0x554FC3FF)
        val chipLp = LinearLayout.LayoutParams(dp(86), dp(36))
        panelBody.addView(chip, chipLp)

        val scroll = ScrollView(this)
        val grid = GridLayout(this)
        grid.columnCount = 5
        grid.useDefaultMargins = false

        val startRaw = (episodeCursor - 22).coerceIn(1, total)
        val endRaw = (startRaw + 44).coerceAtMost(total)
        val start = (endRaw - 44).coerceAtLeast(1)
        for (ep in start..endRaw) {
            val row = label("EPISODE\n$ep", 13f, Color.WHITE, true)
            row.gravity = Gravity.CENTER
            row.maxLines = 2
            row.background = rowBg(ep == episodeCursor)
            val lp = GridLayout.LayoutParams()
            lp.width = dp(78)
            lp.height = dp(58)
            lp.setMargins(dp(5), dp(5), dp(5), dp(5))
            grid.addView(row, lp)
        }

        scroll.addView(grid)
        val scrollLp = LinearLayout.LayoutParams(-1, 0, 1f)
        scrollLp.setMargins(0, dp(18), 0, 0)
        panelBody.addView(scroll, scrollLp)
        hintText.text = "UP/DOWN/LEFT/RIGHT pilih episode • OK apply • BACK kembali"
    }

    private fun buildChoicePanel(title: String, rows: List<String>, cursor: Int) {
        panelTitle.text = title
        val safeRows = rows.ifEmpty { listOf("Tidak tersedia") }
        safeRows.take(12).forEachIndexed { index, text ->
            val row = label(text, 15f, Color.WHITE, true)
            row.gravity = Gravity.CENTER_VERTICAL
            row.setPadding(dp(16), 0, dp(16), 0)
            row.background = rowBg(index == cursor)
            val lp = LinearLayout.LayoutParams(-1, dp(52))
            lp.setMargins(0, dp(8), 0, 0)
            panelBody.addView(row, lp)
        }
        hintText.text = "UP/DOWN pilih • OK apply • BACK kembali"
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
            "Kembali ke kontrol"
        )
    }

    private fun allowMove(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastMoveMs < 90L) return false
        lastMoveMs = now
        return true
    }

    private fun moveDock(delta: Int) {
        if (!allowMove()) return
        selectedControl = (selectedControl + delta).coerceIn(0, 8)
        setMode(Mode.DOCK)
    }

    private fun movePanel(delta: Int) {
        if (!allowMove()) return
        when (mode) {
            Mode.EPISODE -> {
                val total = if (totalEpisodes > 1 && totalEpisodes < 999) totalEpisodes else episode
                episodeCursor = (episodeCursor + delta).coerceIn(1, total)
            }
            Mode.QUALITY -> qualityCursor = (qualityCursor + delta).coerceIn(0, max(0, qualities.size - 1))
            Mode.SUBTITLE -> subtitleCursor = (subtitleCursor + delta).coerceIn(0, max(0, subtitles.size - 1))
            Mode.OPTIONS -> optionCursor = (optionCursor + delta).coerceIn(0, 5)
            else -> Unit
        }
        updatePanel()
    }

    private fun togglePlay() {
        val p = player ?: return
        if (p.isPlaying) p.pause() else p.play()
        setMode(Mode.DOCK)
    }

    private fun seekBy(ms: Long) {
        val p = player ?: return
        val duration = if (p.duration > 0) p.duration else Long.MAX_VALUE
        p.seekTo((p.currentPosition + ms).coerceIn(0L, duration))
        setMode(Mode.DOCK)
    }

    private fun changeSpeed() {
        speedIndex = (speedIndex + 1) % speeds.size
        player?.setPlaybackSpeed(speeds[speedIndex])
        setMode(Mode.DOCK)
    }

    private fun toggleFit() {
        fitCover = !fitCover
        playerView.resizeMode = if (fitCover) AspectRatioFrameLayout.RESIZE_MODE_ZOOM else AspectRatioFrameLayout.RESIZE_MODE_FIT
        setMode(Mode.DOCK)
    }

    private fun toggleMute() {
        muted = !muted
        player?.volume = if (muted) 0f else 1f
        setMode(Mode.DOCK)
    }

    private fun applyQuality() {
        val row = qualities.getOrNull(qualityCursor) ?: return
        val p = player
        val pos = p?.currentPosition ?: 0L
        val playing = p?.isPlaying ?: true
        createPlayer(row.url, pos, playing)
        setMode(Mode.DOCK)
    }

    private fun applySubtitle() {
        val p = player
        val pos = p?.currentPosition ?: 0L
        val playing = p?.isPlaying ?: true
        createPlayer(currentUrl, pos, playing)
        setMode(Mode.DOCK)
    }

    private fun selectEpisode() {
        if (episodeCursor == episode) {
            setMode(Mode.DOCK)
            return
        }
        hintText.text = "Episode reload butuh resolver bridge Flutter"
        setMode(Mode.DOCK)
    }

    private fun activateDock() {
        when (selectedControl) {
            0 -> hintText.text = "Prev butuh resolver bridge Flutter"
            1 -> togglePlay()
            2 -> hintText.text = "Next butuh resolver bridge Flutter"
            3 -> setMode(Mode.EPISODE)
            4 -> setMode(Mode.QUALITY)
            5 -> toggleFit()
            6 -> changeSpeed()
            7 -> hintText.text = "Favorite tahap berikutnya"
            8 -> setMode(Mode.OPTIONS)
        }
    }

    private fun activatePanel() {
        when (mode) {
            Mode.EPISODE -> selectEpisode()
            Mode.QUALITY -> applyQuality()
            Mode.SUBTITLE -> applySubtitle()
            Mode.OPTIONS -> when (optionCursor) {
                0 -> changeSpeed()
                1 -> toggleFit()
                2 -> toggleMute()
                3 -> setMode(Mode.QUALITY)
                4 -> setMode(Mode.SUBTITLE)
                5 -> setMode(Mode.DOCK)
            }
            else -> Unit
        }
    }

    private fun back() {
        val now = System.currentTimeMillis()
        if (now - lastBackMs < 350L) return
        lastBackMs = now
        when (mode) {
            Mode.EPISODE, Mode.QUALITY, Mode.SUBTITLE, Mode.OPTIONS -> setMode(Mode.DOCK)
            Mode.DOCK -> setMode(Mode.CLEAN)
            Mode.CLEAN -> finish()
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return true

        when (event.keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                back()
                return true
            }
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_SPACE -> {
                if (event.repeatCount == 0) {
                    if (mode == Mode.CLEAN) togglePlay()
                    else if (mode == Mode.DOCK) activateDock()
                    else activatePanel()
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (mode == Mode.CLEAN) seekBy(-10_000L)
                else if (mode == Mode.DOCK) moveDock(-1)
                else if (mode == Mode.EPISODE) movePanel(-1)
                else setMode(Mode.DOCK)
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (mode == Mode.CLEAN) seekBy(10_000L)
                else if (mode == Mode.DOCK) moveDock(1)
                else if (mode == Mode.EPISODE) movePanel(1)
                else activatePanel()
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (mode == Mode.CLEAN) setMode(Mode.DOCK)
                else if (mode == Mode.DOCK) setMode(Mode.OPTIONS)
                else if (mode == Mode.EPISODE) movePanel(-5)
                else movePanel(-1)
                return true
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (mode == Mode.CLEAN || mode == Mode.DOCK) setMode(Mode.EPISODE)
                else if (mode == Mode.EPISODE) movePanel(5)
                else movePanel(1)
                return true
            }
            KeyEvent.KEYCODE_MENU -> {
                setMode(Mode.OPTIONS)
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
