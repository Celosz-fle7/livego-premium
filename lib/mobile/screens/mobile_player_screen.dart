import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/stream_info.dart';
import '../../models/livego_episode.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../../services/api/api_platform.dart';
import '../../services/content/content_health_service.dart';
import '../../services/image/image_quality_config.dart';
import '../../services/player/player_preferences.dart';
import '../../services/player/playback_timeout_config.dart';
import '../../services/download/download_service.dart';

class MobilePlayerScreen extends StatefulWidget {
  final ContentItem item;
  const MobilePlayerScreen({super.key, required this.item});

  @override
  State<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}

class _MobilePlayerScreenState extends State<MobilePlayerScreen> {
  late Future<_PlayerState> _future;
  int episode = 1;
  int _knownEpisodeCount = 0;
  int _brokenEpisodeSkips = 0;
  String _lastBrokenReason = '';


  @override
  void initState() {
    super.initState();
    episode = LiveGoLocalStore.continueEpisode(widget.item);
    LiveGoLocalStore.addHistory(widget.item);
    _future = _load();
    _warmEpisodeMetadata();
  }

  ContentItem _keepPlayableIdentity(ContentItem detail) {
    return ContentItem(
      id: detail.id.trim().isNotEmpty ? detail.id : widget.item.id,
      title: detail.title.trim().isNotEmpty ? detail.title : widget.item.title,
      source: detail.source.trim().isNotEmpty ? detail.source : widget.item.source,
      category: detail.category.trim().isNotEmpty ? detail.category : widget.item.category,
      description: detail.description.trim().isNotEmpty ? detail.description : widget.item.description,
      posterUrl: detail.posterUrl.trim().isNotEmpty ? detail.posterUrl : widget.item.posterUrl,
      backdropUrl: detail.backdropUrl.trim().isNotEmpty ? detail.backdropUrl : widget.item.backdropUrl,
      rating: detail.rating,
      episodes: detail.episodes > 0 ? detail.episodes : widget.item.episodes,
      updated: detail.updated || widget.item.updated,
      platformSlug: detail.platformSlug.trim().isNotEmpty ? detail.platformSlug : widget.item.platformSlug,
      chapterId: detail.chapterId.trim().isNotEmpty ? detail.chapterId : widget.item.chapterId,
      lang: detail.lang.trim().isNotEmpty ? detail.lang : widget.item.lang,
    );
  }

  Future<void> _warmEpisodeMetadata() async {
    // Keep first playback fast, but fill the episode selector from cached/detail
    // metadata as soon as it is available. We only cache lightweight metadata:
    // id/title/poster/detail + episode numbers. Signed video URLs are always
    // fetched fresh when an episode is played.
    try {
      final detail = _keepPlayableIdentity(
        await LiveGoCatalog.detail(widget.item).timeout(PlaybackTimeoutConfig.detailBackground),
      );
      final detailCount = detail.episodes;
      if (mounted && detailCount > 1 && detailCount != _knownEpisodeCount) {
        setState(() => _knownEpisodeCount = detailCount);
      }
      final rows = await LiveGoCatalog.episodes(detail).timeout(PlaybackTimeoutConfig.episodeListBackground);
      final count = rows.length > 1 ? rows.length : detailCount;
      if (!mounted || count <= 1) return;
      if (count != _knownEpisodeCount) {
        setState(() => _knownEpisodeCount = count);
      }
    } catch (e) {
      debugPrint('LIVEGO PLAYER episode metadata warm skipped: $e');
    }
  }

  Future<_PlayerState> _load() async {
    await PlayerPreferences.load();
    LiveGoSettings.quality = PlayerPreferences.quality;

    final requestedEpisode = episode <= 0 ? 1 : episode;
    final fastPlayable = ContentItem(
      id: widget.item.id,
      title: widget.item.title,
      source: widget.item.source,
      category: widget.item.category,
      description: widget.item.description,
      posterUrl: widget.item.posterUrl,
      backdropUrl: widget.item.backdropUrl,
      rating: widget.item.rating,
      episodes: widget.item.episodes,
      updated: widget.item.updated,
      platformSlug: widget.item.platformSlug,
      chapterId: '$requestedEpisode',
      lang: widget.item.lang,
    );

    // First playback must not wait for detail/allepisode. Tembak /episode
    // singkat dulu; kalau kosong baru fallback normal. Metadata tetap di-warm
    // lewat _warmEpisodeMetadata() dan tidak menahan video jalan.
    var stream = await LiveGoCatalog.fastStreamInfo(
      fastPlayable,
      chapterId: '$requestedEpisode',
      timeout: PlaybackTimeoutConfig.directEpisode,
    ).timeout(
      PlaybackTimeoutConfig.directEpisode,
      onTimeout: () => StreamInfo.empty,
    );

    if (stream.url.isEmpty) {
      stream = await LiveGoCatalog.streamInfo(fastPlayable, chapterId: '$requestedEpisode')
          .timeout(PlaybackTimeoutConfig.fallbackStream, onTimeout: () => StreamInfo.empty);
    }

    final total = stream.totalEpisodes > widget.item.episodes
        ? stream.totalEpisodes
        : (widget.item.episodes <= 0 ? 1 : widget.item.episodes);
    if (total > 1 && mounted && total != _knownEpisodeCount) {
      Future.microtask(() {
        if (mounted) setState(() => _knownEpisodeCount = total);
      });
    }

    final playable = ContentItem(
      id: widget.item.id,
      title: widget.item.title,
      source: widget.item.source,
      category: widget.item.category,
      description: widget.item.description,
      posterUrl: widget.item.posterUrl,
      backdropUrl: widget.item.backdropUrl,
      rating: widget.item.rating,
      episodes: total,
      updated: widget.item.updated,
      platformSlug: widget.item.platformSlug,
      chapterId: '$requestedEpisode',
      lang: widget.item.lang,
    );
    return _PlayerState(item: playable, stream: stream);
  }

  void _selectEpisode(int value, {bool autoSkipped = false}) {
    if (!autoSkipped) {
      _brokenEpisodeSkips = 0;
      _lastBrokenReason = '';
    }
    setState(() {
      episode = value.clamp(1, 9999);
      _future = _load();
    });
  }

  Future<void> _markPlayable() async {
    _brokenEpisodeSkips = 0;
    _lastBrokenReason = '';
    await ContentHealthService.markPlayable(widget.item);
  }

  Future<void> _handleBrokenEpisode(String reason) async {
    _lastBrokenReason = reason;

    if (!ContentHealthService.shouldAutoSkip(reason)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koneksi/server sedang bermasalah. Konten tidak disembunyikan.')),
      );
      return;
    }

    _brokenEpisodeSkips += 1;
    final total = _knownEpisodeCount > widget.item.episodes ? _knownEpisodeCount : widget.item.episodes;

    if (_brokenEpisodeSkips >= 3 || episode >= total) {
      debugPrint(
        'LIVEGO MOBILE PLAYER source_error_no_hide reason=$_lastBrokenReason '
        'episode=$episode total=$total',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Source gagal, konten tidak disembunyikan selama test mapping API.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Episode $episode gagal, mencoba Episode ${episode + 1}...')),
    );
    _selectEpisode(episode + 1, autoSkipped: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayerState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final state = snap.data;
        var item = state?.item ?? widget.item;
        if (_knownEpisodeCount > item.episodes) {
          item = ContentItem(
            id: item.id,
            title: item.title,
            source: item.source,
            category: item.category,
            description: item.description,
            posterUrl: item.posterUrl,
            backdropUrl: item.backdropUrl,
            rating: item.rating,
            episodes: _knownEpisodeCount,
            updated: item.updated,
            platformSlug: item.platformSlug,
            chapterId: item.chapterId,
            lang: item.lang,
          );
        }
        final stream = state?.stream ?? StreamInfo.empty;

        return Scaffold(
          backgroundColor: Colors.black,
          body: _PlayerSurface(
              key: ValueKey('mobile-player-${widget.item.id}'),
              item: item,
              loading: loading,
              stream: stream,
              episode: episode,
              onBack: () => Navigator.pop(context),
              onEpisode: _selectEpisode,
              onAutoNext: (LiveGoSettings.autoNextEnabled && episode < item.episodes) ? () => _selectEpisode(episode + 1) : null,
              onSkipBroken: (reason) => unawaited(_handleBrokenEpisode(reason)),
              onPlayable: () => unawaited(_markPlayable()),
            ),
        );
      },
    );
  }
}

class _PlayerSurface extends StatefulWidget {
  final ContentItem item;
  final bool loading;
  final StreamInfo stream;
  final int episode;
  final VoidCallback onBack;
  final ValueChanged<int> onEpisode;
  final VoidCallback? onAutoNext;
  final ValueChanged<String>? onSkipBroken;
  final VoidCallback? onPlayable;

  const _PlayerSurface({
    super.key,
    required this.item,
    required this.loading,
    required this.stream,
    required this.episode,
    required this.onBack,
    required this.onEpisode,
    required this.onAutoNext,
    required this.onSkipBroken,
    required this.onPlayable,
  });

  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface> {
  VideoPlayerController? _controller;
  Timer? _timer;
  Timer? _autoQualityTimer;
  Timer? _errorSkipTimer;
  String _activeUrl = '';
  String _error = '';
  bool _controls = true;
  bool _buffering = true;
  bool _muted = false;
  bool _fitCover = false;
  bool _landscape = false;
  bool _autoNextDone = false;
  bool _autoSkipFailedDone = false;
  bool _locked = false;
  String _quality = PlayerPreferences.quality;
  bool _subtitleEnabled = PlayerPreferences.subtitleEnabled;
  String _subtitleLanguage = PlayerPreferences.subtitleLanguage;
  String _audioTrack = PlayerPreferences.audioTrack;
  double _speed = PlayerPreferences.speed;
  Duration _lastProgressSaved = Duration.zero;
  DateTime _lastTapLeft = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTapRight = DateTime.fromMillisecondsSinceEpoch(0);
  int _selectedSubtitleIndex = -1;
  List<_SubtitleCue> _subtitleCues = const <_SubtitleCue>[];
  String _activeSubtitleText = '';
  String _subtitleStatus = 'Tidak tersedia';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    if (!widget.loading && widget.stream.url.isNotEmpty) {
      _openStream();
    } else {
      _buffering = widget.loading;
    }
    _startTimer();
  }


  Future<void> _loadPreferences() async {
    await PlayerPreferences.load();
    if (!mounted) return;
    setState(() {
      _quality = PlayerPreferences.quality;
      _subtitleEnabled = PlayerPreferences.subtitleEnabled;
      _subtitleLanguage = PlayerPreferences.subtitleLanguage;
      _audioTrack = PlayerPreferences.audioTrack.toLowerCase() == 'mute' ? 'Source' : PlayerPreferences.audioTrack;
      _muted = PlayerPreferences.audioTrack.toLowerCase() == 'mute';
      _speed = PlayerPreferences.speed;
    });
    await _controller?.setPlaybackSpeed(_speed);
    await _controller?.setVolume(_muted ? 0 : 1);
  }

  @override
  void didUpdateWidget(covariant _PlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.loading && (oldWidget.loading || oldWidget.stream.url != widget.stream.url)) {
      _openStream();
    }
  }

  Future<void> _openStream() async {
    _autoQualityTimer?.cancel();
    _errorSkipTimer?.cancel();
    await _controller?.dispose();
    _controller = null;
    _error = '';
    _buffering = true;
    _autoNextDone = false;
    _autoSkipFailedDone = false;
    _activeUrl = '';
    if (mounted) setState(() {});

    final url = _resolvedInitialUrl();
    if (url.isEmpty) {
      _error = 'Stream belum tersedia dari API.';
      _buffering = false;
      if (mounted) setState(() {});
      _scheduleSkipBrokenEpisode('stream_empty');
      return;
    }

    await _openResolvedUrl(url, resume: true, autoplay: true);
    unawaited(_preparePreferredSubtitle());
    _scheduleAutoQualityUpgrade();
  }

  String _resolvedInitialUrl() {
    final url = _quality.toLowerCase() == 'auto'
        ? widget.stream.autoStartUrl
        : widget.stream.urlForQuality(_quality);
    _logFreeReelsPlayerUrl('PLAYER_URL_RESOLVED', url);
    return url;
  }

  void _logFreeReelsPlayerUrl(String stage, String url) {
    if (widget.item.platformSlug != 'freereels') return;
    final playbackType = LiveGoApiPlatforms.bySlug(widget.item.platformSlug).videoType.name;
    debugPrint(
      'LIVEGO FREEREELS $stage itemId=${widget.item.id} chapterId=${widget.item.chapterId} '
      'finalUrl=$url playbackType=$playbackType',
    );
  }

  Future<void> _openResolvedUrl(String url, {required bool resume, required bool autoplay}) async {
    try {
      _activeUrl = url;
      _logFreeReelsPlayerUrl('PLAYER_OPEN', url);
      _logStreamUrl('open_stream', url);
      final old = _controller;
      old?.removeListener(_listen);
      await old?.dispose();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: widget.stream.headers.isEmpty ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'} : widget.stream.headers,
      );
      _controller = controller;
      controller.addListener(_listen);
      await controller.initialize().timeout(PlaybackTimeoutConfig.controllerInit);
      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(_muted ? 0 : 1);
      if (resume) {
        final saved = LiveGoLocalStore.progressFor(widget.item);
        if (saved != null && saved.episode == widget.episode && saved.position.inSeconds > 5) {
          await controller.seekTo(saved.position);
        }
      }
      if (autoplay) await controller.play();
      _errorSkipTimer?.cancel();
      widget.onPlayable?.call();
      if (mounted) setState(() => _buffering = false);
    } catch (e) {
      _error = '$e';
      _buffering = false;
      if (mounted) setState(() {});
      _logStreamUrl('source_error', url, error: e);
      _scheduleSkipBrokenEpisode('$e');
    }
  }

  void _logStreamUrl(String event, String url, {Object? error}) {
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      uri = null;
    }
    final host = uri?.host.isNotEmpty == true ? uri!.host : '-';
    final path = uri?.path.isNotEmpty == true ? uri!.path : url;
    final tail = path.length <= 48 ? path : path.substring(path.length - 48);
    debugPrint(
      'LIVEGO MOBILE PLAYER $event host=$host tail=$tail'
      '${error == null ? '' : ' error=$error'}',
    );
  }

  void _scheduleSkipBrokenEpisode(String reason) {
    if (_autoSkipFailedDone || widget.onSkipBroken == null) return;
    _autoSkipFailedDone = true;
    _errorSkipTimer?.cancel();
    _errorSkipTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      widget.onSkipBroken?.call(reason);
    });
  }

  void _scheduleAutoQualityUpgrade() {
    _autoQualityTimer?.cancel();
    if (_quality.toLowerCase() != 'auto') return;
    final best = widget.stream.autoBestUrl;
    if (best.isEmpty || best == _activeUrl) return;

    _autoQualityTimer = Timer(const Duration(seconds: 18), () async {
      final c = _controller;
      if (!mounted || c == null || !c.value.isInitialized || _quality.toLowerCase() != 'auto') return;
      if (c.value.position.inSeconds < 12 || c.value.isBuffering) return;
      final pos = c.value.position;
      final wasPlaying = c.value.isPlaying;
      setState(() => _buffering = true);
      await _openResolvedUrl(best, resume: false, autoplay: wasPlaying);
      final next = _controller;
      if (next != null && next.value.isInitialized) {
        await next.seekTo(pos);
        if (wasPlaying) await next.play();
      }
      if (mounted) setState(() => _buffering = false);
    });
  }

  void _listen() {
    final c = _controller;
    if (!mounted || c == null) return;
    final value = c.value;
    if (_buffering != value.isBuffering) setState(() => _buffering = value.isBuffering);
    if (value.isInitialized) {
      _syncSubtitleAt(value.position);
    }
    if (value.isInitialized && (value.position - _lastProgressSaved).inSeconds.abs() >= 5) {
      _lastProgressSaved = value.position;
      LiveGoLocalStore.saveProgress(widget.item, widget.episode, value.position, value.duration);
    }
    final duration = value.duration;
    if (!_autoNextDone && widget.onAutoNext != null && duration.inSeconds > 15) {
      final remaining = duration - value.position;
      if (remaining.inSeconds <= 2 && value.position.inSeconds > 8) {
        _autoNextDone = true;
        LiveGoLocalStore.markEpisodeComplete(widget.item, widget.episode);
        widget.onAutoNext?.call();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 12), () {
      final controller = _controller;
      final keepVisible = controller != null && controller.value.isInitialized && !controller.value.isPlaying;
      if (mounted && _controls && !keepVisible) setState(() => _controls = false);
    });
  }

  void _showControls() {
    setState(() => _controls = true);
    _startTimer();
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _startTimer();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
    _showControls();
    setState(() {});
  }

  Future<void> _seek(int seconds) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final target = c.value.position + Duration(seconds: seconds);
    await c.seekTo(target < Duration.zero ? Duration.zero : target);
    _showControls();
  }

  void _doubleTapSeek(bool right) {
    final now = DateTime.now();
    final last = right ? _lastTapRight : _lastTapLeft;
    if (now.difference(last).inMilliseconds < 320) _seek(right ? 10 : -10);
    if (right) {
      _lastTapRight = now;
    } else {
      _lastTapLeft = now;
    }
  }

  Future<void> _holdSpeed(bool fast) async {
    final c = _controller;
    if (c == null) return;
    _speed = fast ? 2.0 : 1.0;
    await c.setPlaybackSpeed(_speed);
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null) return;
    _muted = !_muted;
    await c.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
    _showControls();
  }

  Future<void> _toggleLandscape() async {
    _landscape = !_landscape;
    if (!_landscape) _locked = false;
    if (_landscape) {
      _fitCover = false;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
    _showControls();
  }

  Future<void> _togglePortraitFull() async {
    _fitCover = !_fitCover;
    if (!_fitCover) _locked = false;
    if (_fitCover) {
      _landscape = false;
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
    _showControls();
  }

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      _controls = !_locked;
    });
    if (_locked) {
      _timer?.cancel();
    } else {
      _startTimer();
    }
  }

  Future<void> _downloadCurrentEpisode() async {
    _showControls();
    if (widget.stream.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream belum tersedia dari API.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download dimulai...')));
    final result = await DownloadService.enqueue(
      item: widget.item,
      episode: widget.episode,
      stream: widget.stream,
      quality: _quality,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.status == DownloadStatus.completed ? 'Download selesai.' : 'Download: ${result.error.isEmpty ? result.status.name : result.error}'),
    ));
  }

  void _openPlayerSettings() {
    _showControls();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        final subtitles = widget.stream.subtitles;
        final subtitleText = !_subtitleEnabled
            ? 'Mati'
            : (subtitles.isEmpty ? 'Tidak tersedia' : (_subtitleStatus.isNotEmpty ? _subtitleStatus : _subtitleLanguage));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pengaturan Player', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                _SheetRow(title: 'Kualitas Video', value: _quality, onTap: _qualityMenu),
                _SheetRow(title: 'Subtitle', value: subtitleText, onTap: _subtitleMenu),
                _SheetRow(title: 'Audio Track', value: _audioTrack, onTap: _audioMenu),
                _SheetRow(title: 'Kecepatan Pemutaran', value: '${_speed.toStringAsFixed(1)}x', onTap: _speedMenu),
                _SheetRow(title: 'Volume', value: _muted ? 'Mute' : 'Normal', onTap: _toggleMute),
                _SheetRow(
                  title: 'Auto Next',
                  value: LiveGoSettings.autoNextEnabled ? 'Aktif' : 'Mati',
                  onTap: () {
                    setState(() => LiveGoSettings.autoNextEnabled = !LiveGoSettings.autoNextEnabled);
                    Navigator.pop(context);
                    _openPlayerSettings();
                  },
                ),
                _SheetRow(
                  title: 'Mode Layar',
                  value: _fitCover ? 'Full Portrait' : (_landscape ? 'Landscape' : 'Normal'),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePortraitFull();
                  },
                ),
                _SheetRow(
                  title: 'Rotasi',
                  value: _landscape ? 'Landscape' : 'Portrait',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleLandscape();
                  },
                ),
                _SheetRow(
                  title: 'Download Episode',
                  value: 'Mulai',
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_downloadCurrentEpisode());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _qualityMenu() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            runSpacing: 12,
            spacing: 10,
            children: [
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Kualitas Video',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Mode Auto mulai dari kualitas ringan agar cepat play, lalu naik otomatis ke kualitas terbaik saat buffer sudah stabil. Manual 480p/720p/1080p memakai stream provider kalau tersedia.',
                  style: TextStyle(color: Colors.white60, height: 1.35),
                ),
              ),
              for (final label in _qualityLabels())
                _QualityChip(label: label, current: _quality, onPick: (v) => Navigator.pop(context, v)),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _quality = picked;
        _buffering = true;
      });
      LiveGoSettings.quality = picked;
      await PlayerPreferences.setQuality(picked);

      final url = picked.toLowerCase() == 'auto'
          ? widget.stream.autoStartUrl
          : widget.stream.urlForQuality(picked);
      if (url.isNotEmpty && url != _activeUrl) {
        final c = _controller;
        final pos = c?.value.position ?? Duration.zero;
        final wasPlaying = c?.value.isPlaying ?? true;
        await _openResolvedUrl(url, resume: false, autoplay: wasPlaying);
        final next = _controller;
        if (next != null && next.value.isInitialized && pos > Duration.zero) {
          await next.seekTo(pos);
          if (wasPlaying) await next.play();
        }
      }
      _scheduleAutoQualityUpgrade();
    }
    _showControls();
  }

  List<String> _qualityLabels() {
    final labels = <String>['Auto'];
    for (final quality in widget.stream.qualities) {
      final label = quality.label.trim();
      if (label.isEmpty) continue;
      if (!labels.any((e) => e.toLowerCase() == label.toLowerCase())) {
        labels.add(label);
      }
    }
    if (labels.length == 1) labels.add('Source');
    return labels;
  }

  Future<void> _subtitleMenu() async {
    final subtitles = widget.stream.subtitles;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Pilih Subtitle', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _OptionTile(label: 'Matikan', selected: !_subtitleEnabled, onTap: () => Navigator.pop(context, 'OFF')),
              if (subtitles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Subtitle belum tersedia dari source ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                )
              else
                ...subtitles.map((e) => _OptionTile(
                      label: e.language.toUpperCase(),
                      selected: _subtitleEnabled && _subtitleLanguage.toLowerCase() == e.language.toLowerCase(),
                      onTap: () => Navigator.pop(context, e.language),
                    )),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      if (picked == 'OFF') {
        await _applySubtitle(-1);
      } else {
        final index = subtitles.indexWhere((e) => e.language.toLowerCase() == picked.toLowerCase());
        await _applySubtitle(index < 0 ? 0 : index);
      }
    }
    _showControls();
  }

  Future<void> _preparePreferredSubtitle() async {
    if (!mounted) return;
    final subtitles = widget.stream.subtitles;
    if (!_subtitleEnabled || subtitles.isEmpty) {
      setState(() {
        _selectedSubtitleIndex = -1;
        _subtitleCues = const <_SubtitleCue>[];
        _activeSubtitleText = '';
        _subtitleStatus = subtitles.isEmpty ? 'Tidak tersedia' : 'OFF';
      });
      return;
    }

    var index = 0;
    final preferred = _subtitleLanguage.toLowerCase();
    if (preferred.isNotEmpty && preferred != 'auto') {
      final found = subtitles.indexWhere((e) => e.language.toLowerCase().contains(preferred));
      if (found >= 0) index = found;
    }
    await _applySubtitle(index);
  }

  Future<void> _applySubtitle(int trackIndex) async {
    if (trackIndex < 0) {
      setState(() {
        _subtitleEnabled = false;
        _subtitleLanguage = 'OFF';
        _selectedSubtitleIndex = -1;
        _subtitleCues = const <_SubtitleCue>[];
        _activeSubtitleText = '';
        _subtitleStatus = 'OFF';
        LiveGoSettings.subtitlesEnabled = false;
      });
      await PlayerPreferences.setSubtitle(enabled: false, language: 'OFF');
      return;
    }

    if (trackIndex >= widget.stream.subtitles.length) {
      setState(() => _subtitleStatus = 'Tidak tersedia');
      return;
    }

    final track = widget.stream.subtitles[trackIndex];
    setState(() {
      _subtitleEnabled = true;
      _subtitleLanguage = track.language;
      _selectedSubtitleIndex = trackIndex;
      _subtitleCues = const <_SubtitleCue>[];
      _activeSubtitleText = '';
      _subtitleStatus = 'Memuat ${track.language}...';
      LiveGoSettings.subtitlesEnabled = true;
    });
    await PlayerPreferences.setSubtitle(enabled: true, language: track.language);

    try {
      final raw = await _fetchSubtitleText(track.url).timeout(PlaybackTimeoutConfig.subtitleFetch);
      final cues = _parseSubtitle(raw);
      if (!mounted || _selectedSubtitleIndex != trackIndex) return;
      setState(() {
        _subtitleCues = cues;
        _subtitleStatus = cues.isEmpty ? 'Subtitle kosong' : track.language;
      });
      final pos = _controller?.value.position;
      if (pos != null) _syncSubtitleAt(pos, force: true);
    } catch (e) {
      if (!mounted || _selectedSubtitleIndex != trackIndex) return;
      setState(() => _subtitleStatus = 'Gagal subtitle');
    }
  }

  Future<String> _fetchSubtitleText(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'okhttp/4.12.0');
      req.headers.set('Accept', '*/*');
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      return res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  List<_SubtitleCue> _parseSubtitle(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'^WEBVTT.*?\n', dotAll: true), '');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final cues = <_SubtitleCue>[];
    for (final block in blocks) {
      final lines = block.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final timeIndex = lines.indexWhere((e) => e.contains('-->'));
      if (timeIndex < 0) continue;
      final parts = lines[timeIndex].split('-->');
      if (parts.length < 2) continue;
      final start = _parseSubtitleTime(parts[0].trim());
      final end = _parseSubtitleTime(parts[1].split(RegExp(r'\s+')).first.trim());
      if (start == null || end == null || end <= start) continue;
      final text = lines.skip(timeIndex + 1).join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
      if (text.isEmpty) continue;
      cues.add(_SubtitleCue(start: start, end: end, text: text));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  Duration? _parseSubtitleTime(String raw) {
    final clean = raw.replaceAll(',', '.').trim();
    final parts = clean.split(':');
    if (parts.length < 2) return null;
    var hours = 0;
    var minutes = 0;
    var secondsRaw = '';
    if (parts.length == 3) {
      hours = int.tryParse(parts[0]) ?? 0;
      minutes = int.tryParse(parts[1]) ?? 0;
      secondsRaw = parts[2];
    } else {
      minutes = int.tryParse(parts[0]) ?? 0;
      secondsRaw = parts[1];
    }
    final secParts = secondsRaw.split('.');
    final seconds = int.tryParse(secParts[0]) ?? 0;
    final millis = secParts.length > 1
        ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0
        : 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  void _syncSubtitleAt(Duration position, {bool force = false}) {
    if (_subtitleCues.isEmpty || !_subtitleEnabled || !LiveGoSettings.subtitlesEnabled) {
      if (_activeSubtitleText.isNotEmpty || force) {
        if (mounted) setState(() => _activeSubtitleText = '');
      }
      return;
    }
    String next = '';
    for (final cue in _subtitleCues) {
      if (position >= cue.start && position <= cue.end) {
        next = cue.text;
        break;
      }
    }
    if (next != _activeSubtitleText && mounted) {
      setState(() => _activeSubtitleText = next);
    }
  }

  Future<void> _audioMenu() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Pilih Audio Track', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _OptionTile(label: 'Source / Default', selected: _audioTrack == 'Source', onTap: () => Navigator.pop(context, 'Source')),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Mute ada di menu Volume. Audio Track khusus untuk bahasa suara video seperti Indonesia, English, Mandarin kalau provider mengirim track terpisah.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      _audioTrack = picked;
      await PlayerPreferences.setAudioTrack(picked);
      if (mounted) setState(() {});
    }
    _showControls();
  }

  Future<void> _drmMenu() async {
    final values = const ['Auto', 'Paksa L3', 'Nonaktifkan Paksa L3'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Mode Widevine DRM', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              for (final v in values) _OptionTile(label: v, selected: LiveGoSettings.drmMode == v, onTap: () => Navigator.pop(context, v)),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => LiveGoSettings.drmMode = picked);
    _showControls();
  }

  void _speedMenu() async {
    final values = [1.0, 1.25, 1.5, 2.0];
    final next = values[(values.indexOf(_speed) + 1) % values.length];
    _speed = next;
    await _controller?.setPlaybackSpeed(next);
    await PlayerPreferences.setSpeed(next);
    _showControls();
  }

  void _showEpisodes() {
    _showControls();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Pilih Episode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  itemCount: widget.item.episodes.clamp(1, 240).toInt(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.35),
                  itemBuilder: (_, i) {
                    final ep = i + 1;
                    final active = ep == widget.episode;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onEpisode(ep);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? AppTheme.cyan : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? Colors.transparent : Colors.white12),
                        ),
                        child: Text('$ep', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoQualityTimer?.cancel();
    _errorSkipTimer?.cancel();
    _controller?.removeListener(_listen);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final image = widget.item.backdropUrl.isNotEmpty ? widget.item.backdropUrl : widget.item.posterUrl;

    return PopScope(
      canPop: !_controls && !_locked,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_locked) {
          setState(() {
            _locked = false;
            _controls = true;
          });
          _startTimer();
          return;
        }
        if (_controls) {
          setState(() => _controls = false);
          _timer?.cancel();
        }
      },
      child: GestureDetector(
        onTap: _locked ? null : _toggleControls,
        child: LayoutBuilder(
          builder: (context, box) {
            final screenW = box.maxWidth;
            final screenH = box.maxHeight;
            final controller = c;
            final videoRatio = ready && controller != null && controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 9 / 16;
            final isPortraitVideo = videoRatio < 1.0;
            final fullSurface = _fitCover || _landscape;

            double playerW = screenW;
            double playerH = screenH;
            if (!fullSurface) {
              if (isPortraitVideo) {
                playerH = screenH * 0.80;
                playerW = playerH * videoRatio;
                final maxW = screenW * 0.96;
                if (playerW > maxW) {
                  playerW = maxW;
                  playerH = playerW / videoRatio;
                }
              } else {
                playerW = screenW * 0.94;
                playerH = playerW / videoRatio;
                final maxH = screenH * 0.72;
                if (playerH > maxH) {
                  playerH = maxH;
                  playerW = playerH * videoRatio;
                }
              }
            }

            final videoLayer = ready && controller != null
                ? ClipRect(
                    child: _fitCover
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: controller.value.size.width,
                              height: controller.value.size.height,
                              child: VideoPlayer(controller),
                            ),
                          )
                        : Center(
                            child: AspectRatio(
                              aspectRatio: videoRatio,
                              child: VideoPlayer(controller),
                            ),
                          ),
                  )
                : image.isNotEmpty
                    ? LiveGoCachedImage(url: image, fit: BoxFit.cover, role: LiveGoImageRole.thumbnail)
                    : const ColoredBox(color: Color(0xFF101010));

            final playerStack = Stack(
              fit: StackFit.expand,
              children: [
                videoLayer,
                if (!ready) const DecoratedBox(decoration: BoxDecoration(color: Color(0x88000000))),
                if (!_locked)
                  Row(
                    children: [
                      Expanded(child: GestureDetector(onTap: () => _doubleTapSeek(false), onLongPressStart: (_) => _holdSpeed(true), onLongPressEnd: (_) => _holdSpeed(false), child: const SizedBox.expand())),
                      Expanded(child: GestureDetector(onTap: _togglePlay, child: const SizedBox.expand())),
                      Expanded(child: GestureDetector(onTap: () => _doubleTapSeek(true), onLongPressStart: (_) => _holdSpeed(true), onLongPressEnd: (_) => _holdSpeed(false), child: const SizedBox.expand())),
                    ],
                  ),
                if (widget.loading || _buffering) const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
                if (_error.isNotEmpty) Center(child: Padding(padding: const EdgeInsets.all(18), child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)))),
                if (_activeSubtitleText.isNotEmpty)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: _controls ? 128 : 34,
                    child: _SubtitleOverlay(text: _activeSubtitleText),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  top: (_controls && !_locked) ? 0 : -95,
                  left: 0,
                  right: 0,
                  child: _TopOverlay(
                    title: '${widget.item.title} - Eps ${widget.episode}',
                    onBack: widget.onBack,
                    fitCover: _fitCover,
                    landscape: _landscape,
                    onRotate: _toggleLandscape,
                    onFit: _togglePortraitFull,
                  ),
                ),
                if (_controls && !_locked)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CenterButton(icon: Icons.skip_previous_rounded, enabled: widget.episode > 1, onTap: () => widget.onEpisode(widget.episode - 1)),
                        const SizedBox(width: 30),
                        _MainPlayButton(playing: ready && controller != null && controller.value.isPlaying, onTap: _togglePlay),
                        const SizedBox(width: 30),
                        _CenterButton(icon: Icons.skip_next_rounded, enabled: widget.episode < widget.item.episodes, onTap: () => widget.onEpisode(widget.episode + 1)),
                      ],
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  bottom: (_controls && !_locked) ? 12 : -170,
                  left: 0,
                  right: 0,
                  child: _BottomOverlay(
                    controller: controller,
                    episode: widget.episode,
                    total: widget.item.episodes,
                    quality: _quality,
                    muted: _muted,
                    fitCover: _fitCover,
                    landscape: _landscape,
                    onEpisodes: _showEpisodes,
                    onDownload: _downloadCurrentEpisode,
                    onSettings: _openPlayerSettings,
                    onQuality: _qualityMenu,
                    onSubtitle: _subtitleMenu,
                    onAudio: _audioMenu,
                    onSpeed: _speedMenu,
                    onRotate: _toggleLandscape,
                    onFit: _togglePortraitFull,
                  ),
                ),
                if (fullSurface)
                  Positioned(
                    right: 14,
                    top: (screenH / 2) - 28,
                    child: _LockButton(locked: _locked, onTap: _toggleLock),
                  ),
              ],
            );

            return Container(
              width: screenW,
              height: screenH,
              color: Colors.black,
              alignment: Alignment.center,
              child: fullSurface
                  ? playerStack
                  : SizedBox(
                      width: playerW,
                      height: playerH,
                      child: playerStack,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _WideSeekBar extends StatelessWidget {
  final VideoPlayerController controller;
  const _WideSeekBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final durationMs = value.duration.inMilliseconds <= 0 ? 1 : value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds.clamp(0, durationMs).toDouble();
        return Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(_BottomOverlay._fmt(value.position), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 7,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                  activeTrackColor: AppTheme.cyan,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: AppTheme.cyan,
                  overlayColor: AppTheme.cyan.withOpacity(0.18),
                ),
                child: Slider(
                  min: 0,
                  max: durationMs.toDouble(),
                  value: positionMs,
                  onChanged: (v) => controller.seekTo(Duration(milliseconds: v.toInt())),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(_BottomOverlay._fmt(value.duration), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }
}

class _LockButton extends StatelessWidget {
  final bool locked;
  final VoidCallback onTap;
  const _LockButton({required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.58),
          shape: BoxShape.circle,
          border: Border.all(color: locked ? AppTheme.cyan : Colors.white30, width: locked ? 2 : 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.38), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Icon(locked ? Icons.lock_rounded : Icons.lock_open_rounded, color: locked ? AppTheme.cyan : Colors.white, size: 26),
      ),
    );
  }
}

class _BottomInfoPanel extends StatelessWidget {
  final ContentItem item;
  final StreamInfo stream;
  final int episode;
  final ValueChanged<int> onEpisode;
  const _BottomInfoPanel({required this.item, required this.stream, required this.episode, required this.onEpisode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              ValueListenableBuilder<int>(
                valueListenable: LiveGoLocalStore.version,
                builder: (_, __, ___) {
                  final fav = LiveGoLocalStore.isFavorite(item);
                  return IconButton(onPressed: () => LiveGoLocalStore.toggleFavorite(item), icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? AppTheme.cyan : Colors.white));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${item.source} â€¢ Episode $episode / ${item.episodes} â€¢ ${item.category}', style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(item.description.isEmpty ? 'Deskripsi belum tersedia.' : item.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, height: 1.42)),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: item.episodes.clamp(1, 120).toInt(),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final ep = i + 1;
                final active = ep == episode;
                return GestureDetector(
                  onTap: () => onEpisode(ep),
                  child: Container(
                    width: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                      color: active ? null : AppTheme.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? Colors.transparent : const Color(0xFF2D405C)),
                    ),
                    child: Text('$ep', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopOverlay extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final bool fitCover;
  final bool landscape;
  final VoidCallback onRotate;
  final VoidCallback onFit;
  const _TopOverlay({
    required this.title,
    required this.onBack,
    required this.fitCover,
    required this.landscape,
    required this.onRotate,
    required this.onFit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.only(top: 28, left: 8, right: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.86), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          _TopPill(icon: Icons.screen_rotation_rounded, label: landscape ? 'Land' : 'Rotasi', onTap: onRotate),
          const SizedBox(width: 8),
          _TopPill(icon: fitCover ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, label: fitCover ? 'Fit' : 'Full', onTap: onFit),
        ],
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TopPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.52),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  final VideoPlayerController? controller;
  final int episode;
  final int total;
  final String quality;
  final bool muted;
  final bool fitCover;
  final bool landscape;
  final VoidCallback onEpisodes;
  final VoidCallback onDownload;
  final VoidCallback onSettings;
  final VoidCallback onQuality;
  final VoidCallback onSubtitle;
  final VoidCallback onAudio;
  final VoidCallback onSpeed;
  final VoidCallback onRotate;
  final VoidCallback onFit;
  const _BottomOverlay({required this.controller, required this.episode, required this.total, required this.quality, required this.muted, required this.fitCover, required this.landscape, required this.onEpisodes, required this.onDownload, required this.onSettings, required this.onQuality, required this.onSubtitle, required this.onAudio, required this.onSpeed, required this.onRotate, required this.onFit});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 28, 10, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.86), Colors.black.withOpacity(0.18), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.64),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c != null && c.value.isInitialized)
                _WideSeekBar(controller: c),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _Shortcut(icon: Icons.video_library_rounded, label: 'Episode', onTap: onEpisodes),
                    _Shortcut(icon: Icons.high_quality_rounded, label: quality, onTap: onQuality),
                    _Shortcut(icon: Icons.subtitles_rounded, label: 'Subtitle', onTap: onSubtitle),
                    _Shortcut(icon: Icons.audiotrack_rounded, label: 'Audio', onTap: onAudio),
                    _Shortcut(icon: Icons.speed_rounded, label: 'Speed', onTap: onSpeed),
                    _Shortcut(icon: Icons.tune_rounded, label: 'More', onTap: onSettings),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white24)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CenterButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: enabled ? Colors.black45 : Colors.transparent, shape: BoxShape.circle),
        child: Icon(icon, color: enabled ? Colors.white70 : Colors.white12, size: 30),
      ),
    );
  }
}

class _MainPlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  const _MainPlayButton({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 1.4)),
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 38),
      ),
    );
  }
}


class _SubtitleOverlay extends StatelessWidget {
  final String text;
  const _SubtitleOverlay({required this.text});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.64),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.25,
              decoration: TextDecoration.none,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const _SubtitleCue({required this.start, required this.end, required this.text});
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppTheme.cyan : const Color(0xFF2D405C), width: selected ? 2 : 1),
          ),
          child: Text(
            selected ? 'â–¶  $label' : label,
            style: TextStyle(color: selected ? const Color(0xFF9AF6FF) : Colors.white, fontWeight: selected ? FontWeight.w900 : FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  final String label;
  final String current;
  final ValueChanged<String> onPick;
  const _QualityChip({required this.label, required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final selected = current == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPick(label),
      selectedColor: AppTheme.cyan,
      backgroundColor: const Color(0xFF172131),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  const _SheetRow({required this.title, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      trailing: Text(value, style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900)),
    );
  }
}

class _PlayerState {
  final ContentItem item;
  final StreamInfo stream;
  const _PlayerState({required this.item, required this.stream});
}
