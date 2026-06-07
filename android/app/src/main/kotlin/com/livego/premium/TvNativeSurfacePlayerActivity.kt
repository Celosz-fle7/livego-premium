package com.livego.premium

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.ClipDrawable
import android.graphics.drawable.LayerDrawable
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
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

class TvNativeSurfacePlayerActivity : Activity() {
    private enum class Mode { CLEAN, DOCK, DOCK_PROGRESS, EPISODE, QUALITY, SUBTITLE, AUDIO, OPTIONS }

    private data class QualityRow(val label: String, val url: String)
    private data class SubtitleRow(val label: String, val url: String, val format: String)
    private data class AudioRow(val label: String, val language: String?)

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var topInfo: LinearLayout
    private lateinit var bottomDock: LinearLayout
    private lateinit var sidePanel: LinearLayout
    private lateinit var bottomSheet: LinearLayout
    private lateinit var titleText: TextView
    private lateinit var descText: TextView
    private lateinit var tagRow: LinearLayout
    private lateinit var progressBar: ProgressBar
    private lateinit var leftTime: TextView
    private lateinit var rightTime: TextView
    private lateinit var controlRow: LinearLayout
    private lateinit var sheetTitle: TextView
    private lateinit var sheetBody: GridLayout
    private lateinit var sideTitle: TextView
    private lateinit var sideBody: LinearLayout
    private lateinit var toastText: TextView

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
    private var audioCursor = 0
    private var optionCursor = 0
    private var speedIndex = 1
    private var fitCover = false
    private var muted = false
    private var autoNext = false
    private var mode = Mode.DOCK
    private var lastBackMs = 0L
    private var lastMoveMs = 0L
    private var sentClosed = false
    private var episodeResolveInFlight = false
    private var autoNextRequestedForEpisode = -1

    private val speeds = floatArrayOf(0.75f, 1.0f, 1.25f, 1.5f, 2.0f)
    private val qualities = ArrayList<QualityRow>()
    private val subtitles = ArrayList<SubtitleRow>()
    private val audioRows = ArrayList<AudioRow>()
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

    private val toastHideTask = Runnable {
        toastText.visibility = View.GONE
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

        readHeadersFromIntent()
        readQualitiesFromIntent()
        readSubtitlesFromIntent()

        setContentView(buildRoot())
        createPlayer(currentUrl, keepPositionMs = 0L, playWhenReady = true)

        setMode(Mode.DOCK)
        handler.post(tick)
    }

    private fun readHeadersFromIntent() {
        headers.clear()
        val keys = intent.getStringArrayListExtra("headerKeys") ?: arrayListOf()
        val values = intent.getStringArrayListExtra("headerValues") ?: arrayListOf()
        for (i in 0 until min(keys.size, values.size)) {
            val key = keys[i]
            val value = values[i]
            if (key.isNotBlank() && value.isNotBlank()) headers[key] = value
        }
    }

    private fun readQualitiesFromIntent() {
        val labels = intent.getStringArrayListExtra("qualityLabels") ?: arrayListOf()
        val urls = intent.getStringArrayListExtra("qualityUrls") ?: arrayListOf()
        setQualities(labels, urls, currentUrl)
    }

    private fun readSubtitlesFromIntent() {
        val labels = intent.getStringArrayListExtra("subtitleLabels") ?: arrayListOf()
        val urls = intent.getStringArrayListExtra("subtitleUrls") ?: arrayListOf()
        val formats = intent.getStringArrayListExtra("subtitleFormats") ?: arrayListOf()
        setSubtitles(labels, urls, formats)
    }

    private fun setQualities(labels: List<String>, urls: List<String>, activeUrl: String) {
        qualities.clear()
        qualities.add(QualityRow("Auto", activeUrl))
        for (i in 0 until min(labels.size, urls.size)) {
            val label = labels[i].ifBlank { "Quality ${i + 1}" }
            val url = urls[i]
            if (url.isNotBlank() && qualities.none { it.url == url }) {
                qualities.add(QualityRow(label, url))
            }
        }
        qualityCursor = qualities.indexOfFirst { it.url == activeUrl }.coerceAtLeast(0)
    }

    private fun setSubtitles(labels: List<String>, urls: List<String>, formats: List<String>) {
        subtitles.clear()
        subtitles.add(SubtitleRow("Matikan", "", ""))
        for (i in 0 until min(labels.size, urls.size)) {
            val label = labels[i].ifBlank { "Subtitle ${i + 1}" }
            val url = urls[i]
            val format = formats.getOrNull(i) ?: ""
            if (url.isNotBlank()) subtitles.add(SubtitleRow(label, url, format))
        }
        subtitleCursor = subtitleCursor.coerceIn(0, max(0, subtitles.size - 1))
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

        buildTopInfo(frame)
        buildBottomDock(frame)
        buildSidePanel(frame)
        buildBottomSheet(frame)
        buildToast(frame)
        return frame
    }

    private fun buildTopInfo(frame: FrameLayout) {
        topInfo = LinearLayout(this)
        topInfo.orientation = LinearLayout.VERTICAL
        topInfo.setPadding(dp(46), dp(28), dp(46), dp(18))
        topInfo.background = verticalGradient(0xB0000000.toInt(), 0x16000000)

        titleText = label(titleLine(), 25f, Color.WHITE, true)
        titleText.maxLines = 1
        topInfo.addView(titleText, LinearLayout.LayoutParams(-1, -2))

        descText = label(description.ifBlank { " " }, 14f, 0xFFD4DCE8.toInt(), false)
        descText.maxLines = 2
        val descLp = LinearLayout.LayoutParams(-1, -2)
        descLp.setMargins(0, dp(8), 0, dp(12))
        topInfo.addView(descText, descLp)

        tagRow = LinearLayout(this)
        tagRow.orientation = LinearLayout.HORIZONTAL
        topInfo.addView(tagRow, LinearLayout.LayoutParams(-1, dp(32)))
        updateTags()

        val topParams = FrameLayout.LayoutParams(-1, -2)
        topParams.gravity = Gravity.TOP
        frame.addView(topInfo, topParams)
    }

    private fun buildBottomDock(frame: FrameLayout) {
        bottomDock = LinearLayout(this)
        bottomDock.orientation = LinearLayout.VERTICAL
        bottomDock.setPadding(dp(24), dp(17), dp(24), dp(17))
        bottomDock.background = roundedBg(0xE6071321.toInt(), dp(26), 0x8842D9FF.toInt())

        val timeRow = LinearLayout(this)
        timeRow.orientation = LinearLayout.HORIZONTAL
        timeRow.gravity = Gravity.CENTER_VERTICAL
        leftTime = label("00:00", 17f, 0xFFF2F8FF.toInt(), true)
        rightTime = label("00:00", 17f, 0xFFF2F8FF.toInt(), true)
        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal)
        progressBar.max = 1000
        progressBar.progressDrawable = premiumProgressDrawable()
        timeRow.addView(leftTime, LinearLayout.LayoutParams(dp(82), -2))
        val progressParams = LinearLayout.LayoutParams(0, dp(10), 1f)
        progressParams.setMargins(dp(10), 0, dp(10), 0)
        timeRow.addView(progressBar, progressParams)
        timeRow.addView(rightTime, LinearLayout.LayoutParams(dp(82), -2))
        bottomDock.addView(timeRow, LinearLayout.LayoutParams(-1, -2))

        controlRow = LinearLayout(this)
        controlRow.orientation = LinearLayout.HORIZONTAL
        controlRow.gravity = Gravity.CENTER
        val controlLp = LinearLayout.LayoutParams(-1, dp(68))
        controlLp.setMargins(0, dp(18), 0, 0)
        bottomDock.addView(controlRow, controlLp)

        repeat(10) { index ->
            val width = when (index) {
                1 -> dp(72)
                4 -> dp(106)
                6 -> dp(86)
                8 -> dp(84)
                else -> dp(64)
            }
            val button = label("", 12f, Color.WHITE, true)
            button.gravity = Gravity.CENTER
            button.maxLines = 2
            val lp = LinearLayout.LayoutParams(width, -1)
            if (index > 0) lp.leftMargin = dp(7)
            controlRow.addView(button, lp)
            controlButtons.add(button)
        }

        val dockParams = FrameLayout.LayoutParams(-1, -2)
        dockParams.gravity = Gravity.BOTTOM
        dockParams.leftMargin = dp(24)
        dockParams.rightMargin = dp(24)
        dockParams.bottomMargin = dp(24)
        frame.addView(bottomDock, dockParams)
    }

    private fun buildSidePanel(frame: FrameLayout) {
        sidePanel = LinearLayout(this)
        sidePanel.orientation = LinearLayout.VERTICAL
        sidePanel.setPadding(dp(22), dp(22), dp(22), dp(22))
        sidePanel.background = roundedBg(0xF0071321.toInt(), dp(26), 0x8842D9FF.toInt())
        sidePanel.visibility = View.GONE
        sideTitle = label("Daftar Episode", 23f, Color.WHITE, true)
        sidePanel.addView(sideTitle, LinearLayout.LayoutParams(-1, -2))
        sideBody = LinearLayout(this)
        sideBody.orientation = LinearLayout.VERTICAL
        val bodyLp = LinearLayout.LayoutParams(-1, 0, 1f)
        bodyLp.setMargins(0, dp(16), 0, 0)
        sidePanel.addView(sideBody, bodyLp)
        val params = FrameLayout.LayoutParams(dp(512), -1)
        params.gravity = Gravity.RIGHT
        params.topMargin = dp(24)
        params.rightMargin = dp(24)
        params.bottomMargin = dp(24)
        frame.addView(sidePanel, params)
    }

    private fun buildBottomSheet(frame: FrameLayout) {
        bottomSheet = LinearLayout(this)
        bottomSheet.orientation = LinearLayout.VERTICAL
        bottomSheet.setPadding(dp(24), dp(18), dp(24), dp(20))
        bottomSheet.background = roundedBg(0xF0071321.toInt(), dp(26), 0x8842D9FF.toInt())
        bottomSheet.visibility = View.GONE

        val handle = View(this)
        handle.background = roundedBg(0xCC5DDCFF.toInt(), dp(5), 0x00000000)
        val handleLp = LinearLayout.LayoutParams(dp(130), dp(5))
        handleLp.gravity = Gravity.CENTER_HORIZONTAL
        bottomSheet.addView(handle, handleLp)

        sheetTitle = label("Panel", 23f, Color.WHITE, true)
        sheetTitle.gravity = Gravity.CENTER
        val titleLp = LinearLayout.LayoutParams(-1, -2)
        titleLp.setMargins(0, dp(16), 0, dp(14))
        bottomSheet.addView(sheetTitle, titleLp)

        sheetBody = GridLayout(this)
        sheetBody.columnCount = 5
        bottomSheet.addView(sheetBody, LinearLayout.LayoutParams(-1, -2))

        val params = FrameLayout.LayoutParams(-1, -2)
        params.gravity = Gravity.BOTTOM
        params.leftMargin = dp(24)
        params.rightMargin = dp(24)
        params.bottomMargin = dp(24)
        frame.addView(bottomSheet, params)
    }

    private fun buildToast(frame: FrameLayout) {
        toastText = label("", 13f, Color.WHITE, true)
        toastText.gravity = Gravity.CENTER
        toastText.setPadding(dp(22), dp(12), dp(22), dp(12))
        toastText.background = roundedBg(0xF00B1524.toInt(), dp(18), 0x6642D9FF.toInt())
        toastText.visibility = View.GONE
        val params = FrameLayout.LayoutParams(-2, -2)
        params.gravity = Gravity.CENTER
        frame.addView(toastText, params)
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
        exo.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED && autoNext && autoNextRequestedForEpisode != episode) {
                    autoNextRequestedForEpisode = episode
                    val nextEpisode = episode + 1
                    if (totalEpisodes > 1 && nextEpisode > totalEpisodes) {
                        showToast("Episode terakhir")
                    } else {
                        requestEpisode(nextEpisode)
                    }
                }
                refreshAudioRows()
            }

            override fun onTracksChanged(tracks: androidx.media3.common.Tracks) {
                refreshAudioRows()
            }
        })
        exo.setMediaItem(buildMediaItem(url))
        exo.prepare()
        if (keepPositionMs > 0) exo.seekTo(keepPositionMs)
        exo.playWhenReady = playWhenReady
        exo.setPlaybackSpeed(speeds[speedIndex])
        exo.volume = if (muted) 0f else 1f

        old?.release()
        currentUrl = url
        handler.postDelayed({ refreshAudioRows() }, 1200)
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

    private fun refreshAudioRows() {
        val previous = audioRows.getOrNull(audioCursor)?.label
        audioRows.clear()
        audioRows.add(AudioRow("Auto", null))
        val p = player ?: return

        val seen = HashSet<String>()
        for (group in p.currentTracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO) continue
            for (i in 0 until group.length) {
                if (!group.isTrackSupported(i)) continue
                val format = group.getTrackFormat(i)
                val language = format.language ?: ""
                val labelParts = ArrayList<String>()
                if (language.isNotBlank()) labelParts.add(language)
                if (!format.label.isNullOrBlank()) labelParts.add(format.label!!)
                if (format.channelCount > 0) labelParts.add("${format.channelCount}ch")
                val label = labelParts.joinToString(" ").ifBlank { "Audio ${audioRows.size}" }
                if (seen.add(label)) audioRows.add(AudioRow(label, language.ifBlank { null }))
            }
        }
        audioCursor = audioRows.indexOfFirst { it.label == previous }.takeIf { it >= 0 } ?: 0
    }

    private fun requestEpisode(targetEpisode: Int) {
        if (episodeResolveInFlight) {
            showToast("Masih memuat episode...")
            return
        }

        if (targetEpisode < 1) {
            showToast("Tidak ada episode sebelumnya")
            return
        }

        if (totalEpisodes > 1 && targetEpisode > totalEpisodes) {
            showToast("Episode terakhir")
            return
        }

        if (targetEpisode == episode) {
            showToast("Episode $episode sedang diputar")
            setMode(Mode.DOCK)
            return
        }

        episodeResolveInFlight = true
        showToast("Memuat Episode $targetEpisode...")

        val args = mapOf(
            "episode" to targetEpisode,
            "quality" to (qualities.getOrNull(qualityCursor)?.label ?: "Auto")
        )

        val channel = MainActivity.nativePlayerChannel
        if (channel == null) {
            episodeResolveInFlight = false
            showToast("Resolver Flutter tidak tersedia")
            return
        }

        channel.invokeMethod("resolveEpisode", args, object : MethodChannel.Result {
            override fun success(result: Any?) {
                runOnUiThread {
                    episodeResolveInFlight = false
                    val data = result as? Map<*, *>
                    if (data == null) {
                        showToast("Resolver kosong")
                        return@runOnUiThread
                    }
                    val error = data["error"]?.toString().orEmpty()
                    if (error.isNotBlank()) {
                        showToast(error.take(80))
                        return@runOnUiThread
                    }
                    applyResolvedPayload(data)
                }
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                runOnUiThread {
                    episodeResolveInFlight = false
                    showToast(errorMessage ?: errorCode)
                }
            }

            override fun notImplemented() {
                runOnUiThread {
                    episodeResolveInFlight = false
                    showToast("Resolver episode belum aktif")
                }
            }
        })
    }

    private fun applyResolvedPayload(data: Map<*, *>) {
        val url = data["url"]?.toString().orEmpty()
        if (url.isBlank()) {
            showToast("URL episode kosong")
            return
        }

        title = data["title"]?.toString().orEmpty().ifBlank { title }
        description = data["description"]?.toString().orEmpty()
        source = data["source"]?.toString().orEmpty()
        category = data["category"]?.toString().orEmpty()
        episode = (data["episode"] as? Number)?.toInt() ?: data["episode"]?.toString()?.toIntOrNull() ?: episode
        totalEpisodes = (data["totalEpisodes"] as? Number)?.toInt() ?: data["totalEpisodes"]?.toString()?.toIntOrNull() ?: totalEpisodes
        episodeCursor = episode

        headers.clear()
        val headersMap = data["headers"] as? Map<*, *>
        headersMap?.forEach { (key, value) ->
            val k = key?.toString().orEmpty()
            val v = value?.toString().orEmpty()
            if (k.isNotBlank() && v.isNotBlank()) headers[k] = v
        }

        setQualities(listFrom(data["qualityLabels"]), listFrom(data["qualityUrls"]), url)
        setSubtitles(listFrom(data["subtitleLabels"]), listFrom(data["subtitleUrls"]), listFrom(data["subtitleFormats"]))

        titleText.text = titleLine()
        descText.text = description.ifBlank { " " }
        updateTags()
        autoNextRequestedForEpisode = -1
        createPlayer(url, keepPositionMs = 0L, playWhenReady = true)
        showToast("Episode $episode")
        setMode(Mode.DOCK)
    }

    private fun listFrom(value: Any?): List<String> {
        val list = value as? List<*> ?: return emptyList()
        return list.map { it?.toString().orEmpty() }
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
            setStroke(dp(1), stroke)
        }
    }

    private fun verticalGradient(top: Int, bottom: Int): GradientDrawable {
        return GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(top, bottom))
    }

    private fun premiumProgressDrawable(): LayerDrawable {
        val track = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(0x55304452)
            cornerRadius = dp(8).toFloat()
        }
        val fill = GradientDrawable(
            GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(0xFFB339FF.toInt(), 0xFF35CBFF.toInt())
        ).apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(8).toFloat()
        }
        val clip = ClipDrawable(fill, Gravity.LEFT, ClipDrawable.HORIZONTAL)
        return LayerDrawable(arrayOf(track, clip)).apply {
            setId(0, android.R.id.background)
            setId(1, android.R.id.progress)
        }
    }

    private fun selectedBg(): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(0xFF2ED7FF.toInt(), 0xFF7A5CFF.toInt())
        ).apply {
            cornerRadius = dp(18).toFloat()
            setStroke(dp(2), 0xFFEAFBFF.toInt())
        }
    }

    private fun normalBg(): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(0x66344A5C, 0x55203142)
        ).apply {
            cornerRadius = dp(18).toFloat()
            setStroke(dp(1), 0x334ECFFF)
        }
    }

    private fun rowBg(focused: Boolean): GradientDrawable {
        return if (focused) selectedBg() else GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(0x6632495D, 0x55202D3C)
        ).apply {
            cornerRadius = dp(15).toFloat()
            setStroke(dp(1), 0x334ECFFF)
        }
    }
    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun titleLine(): String = "$title - Ep $episode${if (totalEpisodes > 1 && totalEpisodes < 999) " / $totalEpisodes" else ""}"

    private fun updateTags() {
        tagRow.removeAllViews()
        val tags = ArrayList<String>()
        tags.add("Gratis")
        if (category.isNotBlank()) tags.add(category)
        if (source.isNotBlank()) tags.add(source)
        tags.take(4).forEach { tag ->
            val chip = label(tag, 12f, 0xFFE5E7EB.toInt(), false)
            chip.gravity = Gravity.CENTER
            chip.setPadding(dp(10), 0, dp(10), 0)
            chip.background = roundedBg(0x66304A5C, dp(13), 0x555DDCFF)
            val lp = LinearLayout.LayoutParams(-2, dp(28))
            lp.rightMargin = dp(8)
            tagRow.addView(chip, lp)
        }
    }

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
                sidePanel.visibility = View.GONE
                bottomSheet.visibility = View.GONE
            }
            Mode.DOCK -> {
                topInfo.visibility = View.VISIBLE
                bottomDock.visibility = View.VISIBLE
                sidePanel.visibility = View.GONE
                bottomSheet.visibility = View.GONE
                handler.postDelayed(hideDockTask, 5000)
            }
            Mode.DOCK_PROGRESS -> {
                topInfo.visibility = View.VISIBLE
                bottomDock.visibility = View.VISIBLE
                sidePanel.visibility = View.GONE
                bottomSheet.visibility = View.GONE
            }
            Mode.EPISODE -> {
                topInfo.visibility = View.GONE
                bottomDock.visibility = View.GONE
                sidePanel.visibility = View.VISIBLE
                bottomSheet.visibility = View.GONE
                updateEpisodePanel()
            }
            Mode.QUALITY, Mode.SUBTITLE, Mode.AUDIO, Mode.OPTIONS -> {
                topInfo.visibility = View.VISIBLE
                bottomDock.visibility = View.GONE
                sidePanel.visibility = View.GONE
                bottomSheet.visibility = View.VISIBLE
                updateBottomSheet()
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
        val progressFocused = mode == Mode.DOCK_PROGRESS
        progressBar.alpha = if (progressFocused) 1.0f else 0.82f
        leftTime.setTextColor(if (progressFocused) 0xFF35CBFF.toInt() else Color.WHITE)
        rightTime.setTextColor(if (progressFocused) 0xFF35CBFF.toInt() else Color.WHITE)
        titleText.text = titleLine()
        updateDock()
    }

    private fun updateDock() {
        if (controlButtons.size < 10) return
        val speed = speeds[speedIndex]
        val speedText = if (speed == speed.toInt().toFloat()) "${speed.toInt()}x" else "${speed}x"
        val labels = listOf(
            "‹‹\nPrev",
            if (player?.isPlaying == true) "⏸\nPause" else "▶\nPlay",
            "Next\n››",
            "↻\n$speedText",
            qualities.getOrNull(qualityCursor)?.label ?: "Auto",
            "⛶\n${if (fitCover) "Cover" else "Fit"}",
            "Auto\n${if (autoNext) "ON" else "OFF"}",
            "♪\nAudio",
            "CC\nSub",
            "☰\nEpisode"
        )
        for (i in controlButtons.indices) {
            val b = controlButtons[i]
            b.text = labels[i]
            b.textSize = when (i) {
                1 -> 14.5f
                3 -> 13.0f
                4 -> 14.0f
                8 -> 12.5f
                else -> 12.0f
            }
            val selected = mode == Mode.DOCK && i == selectedControl
            b.background = if (selected) selectedBg() else normalBg()
            b.setTextColor(if (selected) Color.WHITE else 0xFFD8E4F0.toInt())
            b.alpha = if (selected) 1.0f else 0.86f
        }
    }

    private fun updateEpisodePanel() {
        sideBody.removeAllViews()
        sideTitle.text = "Daftar Episode"
        val total = if (totalEpisodes > 1 && totalEpisodes < 999) totalEpisodes else max(episode, 1)

        val chip = label("$total Ep", 13f, 0xFFE9F8FF.toInt(), true)
        chip.gravity = Gravity.CENTER
        chip.background = roundedBg(0x55314257, dp(14), 0x554FC3FF)
        sideBody.addView(chip, LinearLayout.LayoutParams(dp(86), dp(36)))

        val scroll = ScrollView(this)
        val grid = GridLayout(this)
        grid.columnCount = 5

        val startRaw = (episodeCursor - 22).coerceIn(1, total)
        val endRaw = (startRaw + 44).coerceAtMost(total)
        val start = (endRaw - 44).coerceAtLeast(1)

        for (ep in start..endRaw) {
            val row = label("EPISODE\n$ep", 12.5f, Color.WHITE, true)
            row.gravity = Gravity.CENTER
            row.maxLines = 2
            row.background = rowBg(ep == episodeCursor)
            if (ep == episode) row.text = "DIPUTAR\n$ep"
            val lp = GridLayout.LayoutParams()
            lp.width = dp(80)
            lp.height = dp(60)
            lp.setMargins(dp(5), dp(5), dp(5), dp(5))
            grid.addView(row, lp)
        }

        scroll.addView(grid)
        val scrollLp = LinearLayout.LayoutParams(-1, 0, 1f)
        scrollLp.setMargins(0, dp(18), 0, 0)
        sideBody.addView(scroll, scrollLp)
    }

    private fun updateBottomSheet() {
        sheetBody.removeAllViews()
        when (mode) {
            Mode.QUALITY -> buildSheet("Kualitas Video", qualities.map { it.label }, qualityCursor, 4)
            Mode.SUBTITLE -> buildSheet("CC", subtitles.map { it.label }, subtitleCursor, 4)
            Mode.AUDIO -> {
                refreshAudioRows()
                buildSheet("Audio Track", audioRows.map { it.label }, audioCursor, 2)
            }
            Mode.OPTIONS -> buildSheet("More", optionRows(), optionCursor, 3)
            else -> Unit
        }
    }

    private fun buildSheet(title: String, rows: List<String>, cursor: Int, columns: Int) {
        sheetTitle.text = title
        sheetBody.columnCount = columns
        val safeRows = rows.ifEmpty { listOf("Tidak tersedia") }
        safeRows.forEachIndexed { index, text ->
            val row = label(text, 14.5f, Color.WHITE, true)
            row.gravity = Gravity.CENTER
            row.setPadding(dp(14), 0, dp(14), 0)
            row.background = rowBg(index == cursor)
            val lp = GridLayout.LayoutParams()
            lp.width = when {
                columns <= 2 -> dp(430)
                columns == 3 -> dp(250)
                else -> dp(205)
            }
            lp.height = dp(56)
            lp.setMargins(dp(5), dp(5), dp(5), dp(5))
            sheetBody.addView(row, lp)
        }
    }

    private fun optionRows(): List<String> {
        val speed = speeds[speedIndex]
        val speedText = if (speed == speed.toInt().toFloat()) "${speed.toInt()}x" else "${speed}x"
        return listOf(
            "Speed $speedText",
            "Auto Next ${if (autoNext) "ON" else "OFF"}",
            "Layar ${if (fitCover) "Cover" else "Fit"}",
            "Volume ${if (muted) "Mute" else "Normal"}",
            "Quality",
            "Subtitle",
            "Audio",
            "Kembali"
        )
    }

    private fun showToast(text: String) {
        toastText.text = text
        toastText.visibility = View.VISIBLE
        handler.removeCallbacks(toastHideTask)
        handler.postDelayed(toastHideTask, 1600)
    }

    private fun allowMove(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastMoveMs < 90L) return false
        lastMoveMs = now
        return true
    }

    private fun moveDock(delta: Int) {
        if (!allowMove()) return
        selectedControl = (selectedControl + delta).coerceIn(0, 9)
        setMode(Mode.DOCK)
    }

    private fun movePanel(delta: Int) {
        if (!allowMove()) return
        when (mode) {
            Mode.EPISODE -> {
                val total = if (totalEpisodes > 1 && totalEpisodes < 999) totalEpisodes else episode
                episodeCursor = (episodeCursor + delta).coerceIn(1, total)
                updateEpisodePanel()
            }
            Mode.QUALITY -> {
                qualityCursor = (qualityCursor + delta).coerceIn(0, max(0, qualities.size - 1))
                updateBottomSheet()
            }
            Mode.SUBTITLE -> {
                subtitleCursor = (subtitleCursor + delta).coerceIn(0, max(0, subtitles.size - 1))
                updateBottomSheet()
            }
            Mode.AUDIO -> {
                audioCursor = (audioCursor + delta).coerceIn(0, max(0, audioRows.size - 1))
                updateBottomSheet()
            }
            Mode.OPTIONS -> {
                optionCursor = (optionCursor + delta).coerceIn(0, 7)
                updateBottomSheet()
            }
            else -> Unit
        }
    }

    private fun togglePlay() {
        val p = player ?: return
        if (p.isPlaying) p.pause() else p.play()
        setMode(Mode.DOCK)
    }

    private fun seekBy(ms: Long, revealControls: Boolean = true) {
        val p = player ?: return
        val duration = if (p.duration > 0) p.duration else Long.MAX_VALUE
        p.seekTo((p.currentPosition + ms).coerceIn(0L, duration))
        if (revealControls) {
            setMode(Mode.DOCK)
        } else {
            updateProgress()
        }
    }

    private fun changeSpeed() {
        speedIndex = (speedIndex + 1) % speeds.size
        player?.setPlaybackSpeed(speeds[speedIndex])
        showToast("Speed ${speeds[speedIndex]}x")
        setMode(Mode.DOCK)
    }

    private fun toggleFit() {
        fitCover = !fitCover
        playerView.resizeMode = if (fitCover) AspectRatioFrameLayout.RESIZE_MODE_ZOOM else AspectRatioFrameLayout.RESIZE_MODE_FIT
        showToast("Layar: ${if (fitCover) "Cover" else "Fit"}")
        setMode(Mode.DOCK)
    }

    private fun toggleAutoNext() {
        autoNext = !autoNext
        showToast("Auto Next: ${if (autoNext) "ON" else "OFF"}")
        setMode(Mode.DOCK)
    }

    private fun toggleMute() {
        muted = !muted
        player?.volume = if (muted) 0f else 1f
        showToast("Volume: ${if (muted) "Mute" else "Normal"}")
        setMode(Mode.DOCK)
    }

    private fun applyQuality() {
        val row = qualities.getOrNull(qualityCursor) ?: return
        val p = player
        val pos = p?.currentPosition ?: 0L
        val playing = p?.isPlaying ?: true
        createPlayer(row.url, pos, playing)
        showToast("Quality: ${row.label}")
        setMode(Mode.DOCK)
    }

    private fun applySubtitle() {
        val p = player
        val pos = p?.currentPosition ?: 0L
        val playing = p?.isPlaying ?: true
        createPlayer(currentUrl, pos, playing)
        showToast("Subtitle: ${subtitles.getOrNull(subtitleCursor)?.label ?: "OFF"}")
        setMode(Mode.DOCK)
    }

    private fun applyAudio() {
        val row = audioRows.getOrNull(audioCursor) ?: return
        val builder = player?.trackSelectionParameters?.buildUpon() ?: return
        builder.setPreferredAudioLanguage(row.language)
        player?.trackSelectionParameters = builder.build()
        showToast("Audio: ${row.label}")
        setMode(Mode.DOCK)
    }

    private fun activateDock() {
        when (selectedControl) {
            0 -> requestEpisode(episode - 1)
            1 -> togglePlay()
            2 -> requestEpisode(episode + 1)
            3 -> changeSpeed()
            4 -> setMode(Mode.QUALITY)
            5 -> toggleFit()
            6 -> toggleAutoNext()
            7 -> setMode(Mode.AUDIO)
            8 -> setMode(Mode.SUBTITLE)
            9 -> setMode(Mode.EPISODE)
        }
    }

    private fun activatePanel() {
        when (mode) {
            Mode.EPISODE -> requestEpisode(episodeCursor)
            Mode.QUALITY -> applyQuality()
            Mode.SUBTITLE -> applySubtitle()
            Mode.AUDIO -> applyAudio()
            Mode.OPTIONS -> when (optionCursor) {
                0 -> changeSpeed()
                1 -> toggleAutoNext()
                2 -> toggleFit()
                3 -> toggleMute()
                4 -> setMode(Mode.QUALITY)
                5 -> setMode(Mode.SUBTITLE)
                6 -> setMode(Mode.AUDIO)
                7 -> setMode(Mode.DOCK)
            }
            else -> Unit
        }
    }

    private fun back() {
        val now = System.currentTimeMillis()
        if (now - lastBackMs < 350L) return
        lastBackMs = now
        when (mode) {
            Mode.EPISODE, Mode.QUALITY, Mode.SUBTITLE, Mode.AUDIO, Mode.OPTIONS -> setMode(Mode.DOCK)
            Mode.DOCK, Mode.DOCK_PROGRESS -> setMode(Mode.CLEAN)
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
                    when (mode) {
                        Mode.CLEAN -> togglePlay()
                        Mode.DOCK -> activateDock()
                        Mode.DOCK_PROGRESS -> togglePlay()
                        Mode.EPISODE, Mode.QUALITY, Mode.SUBTITLE, Mode.AUDIO, Mode.OPTIONS -> activatePanel()
                    }
                }
                return true
            }

            KeyEvent.KEYCODE_DPAD_LEFT -> {
                when (mode) {
                    Mode.CLEAN -> seekBy(-10_000L, revealControls = false)
                    Mode.DOCK -> moveDock(-1)
                    Mode.DOCK_PROGRESS -> seekBy(-10_000L, revealControls = false)
                    Mode.EPISODE -> movePanel(-1)
                    Mode.QUALITY, Mode.SUBTITLE, Mode.AUDIO, Mode.OPTIONS -> setMode(Mode.DOCK)
                }
                return true
            }

            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                when (mode) {
                    Mode.CLEAN -> seekBy(10_000L, revealControls = false)
                    Mode.DOCK -> moveDock(1)
                    Mode.DOCK_PROGRESS -> seekBy(10_000L, revealControls = false)
                    Mode.EPISODE -> movePanel(1)
                    Mode.QUALITY, Mode.SUBTITLE, Mode.AUDIO, Mode.OPTIONS -> activatePanel()
                }
                return true
            }

            KeyEvent.KEYCODE_DPAD_UP -> {
                when (mode) {
                    // Controls hidden: UP shows controls.
                    Mode.CLEAN -> setMode(Mode.DOCK)

                    // Controls visible: UP goes to progress bar, not More.
                    Mode.DOCK -> setMode(Mode.DOCK_PROGRESS)

                    // Progress focused: UP hides controls.
                    Mode.DOCK_PROGRESS -> setMode(Mode.CLEAN)

                    Mode.EPISODE -> movePanel(-5)
                    Mode.QUALITY, Mode.SUBTITLE, Mode.AUDIO, Mode.OPTIONS -> movePanel(-1)
                }
                return true
            }

            KeyEvent.KEYCODE_DPAD_DOWN -> {
                when (mode) {
                    // Controls hidden: DOWN is quick episode list.
                    Mode.CLEAN -> setMode(Mode.EPISODE)

                    // Controls visible: DOWN must not open episode list.
                    Mode.DOCK -> setMode(Mode.DOCK)

                    // Progress focused: DOWN returns to dock buttons.
                    Mode.DOCK_PROGRESS -> setMode(Mode.DOCK)

                    Mode.EPISODE -> movePanel(5)
                    Mode.QUALITY, Mode.SUBTITLE, Mode.AUDIO, Mode.OPTIONS -> movePanel(1)
                }
                return true
            }

            KeyEvent.KEYCODE_MENU -> {
                setMode(Mode.OPTIONS)
                return true
            }

            KeyEvent.KEYCODE_MEDIA_REWIND -> {
                seekBy(-10_000L, revealControls = mode != Mode.CLEAN && mode != Mode.DOCK_PROGRESS)
                return true
            }

            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                seekBy(10_000L, revealControls = mode != Mode.CLEAN && mode != Mode.DOCK_PROGRESS)
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
        notifyClosed()
        super.onDestroy()
    }

    private fun notifyClosed() {
        if (sentClosed) return
        sentClosed = true
        MainActivity.nativePlayerChannel?.invokeMethod("nativeClosed", emptyMap<String, Any>())
    }
}
