import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/stream_info.dart';

class MobilePlayerScreen extends StatefulWidget {
  final ContentItem item;
  const MobilePlayerScreen({super.key, required this.item});

  @override
  State<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}

class _MobilePlayerScreenState extends State<MobilePlayerScreen> {
  late Future<_PlayerState> _future;
  int episode = 1;

  @override
  void initState() {
    super.initState();
    episode = LiveGoLocalStore.continueEpisode(widget.item);
    LiveGoLocalStore.addHistory(widget.item);
    _future = _load();
  }

  Future<_PlayerState> _load() async {
    final detail = await LiveGoCatalog.detail(widget.item);
    final selected = ContentItem(
      id: detail.id,
      title: detail.title,
      source: detail.source,
      category: detail.category,
      description: detail.description,
      posterUrl: detail.posterUrl,
      backdropUrl: detail.backdropUrl,
      rating: detail.rating,
      episodes: detail.episodes,
      updated: detail.updated,
      platformSlug: detail.platformSlug,
      chapterId: '$episode',
      lang: detail.lang,
    );
    final stream = await LiveGoCatalog.streamInfo(selected, chapterId: '$episode');
    final total = stream.totalEpisodes > selected.episodes ? stream.totalEpisodes : selected.episodes;
    final playable = ContentItem(
      id: selected.id,
      title: selected.title,
      source: selected.source,
      category: selected.category,
      description: selected.description,
      posterUrl: selected.posterUrl,
      backdropUrl: selected.backdropUrl,
      rating: selected.rating,
      episodes: total <= 0 ? 1 : total,
      updated: selected.updated,
      platformSlug: selected.platformSlug,
      chapterId: '$episode',
      lang: selected.lang,
    );
    return _PlayerState(item: playable, stream: stream);
  }

  void _selectEpisode(int value) {
    setState(() {
      episode = value.clamp(1, 9999);
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayerState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final state = snap.data;
        final item = state?.item ?? widget.item;
        final stream = state?.stream ?? StreamInfo.empty;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            bottom: false,
            child: _PlayerSurface(
              key: ValueKey('mobile-player-${stream.url}-$episode'),
              item: item,
              loading: loading,
              stream: stream,
              episode: episode,
              onBack: () => Navigator.pop(context),
              onEpisode: _selectEpisode,
              onAutoNext: (LiveGoSettings.autoNextEnabled && episode < item.episodes) ? () => _selectEpisode(episode + 1) : null,
            ),
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

  const _PlayerSurface({
    super.key,
    required this.item,
    required this.loading,
    required this.stream,
    required this.episode,
    required this.onBack,
    required this.onEpisode,
    required this.onAutoNext,
  });

  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface> {
  VideoPlayerController? _controller;
  Timer? _timer;
  String _error = '';
  bool _controls = true;
  bool _buffering = true;
  bool _muted = false;
  bool _fitCover = false;
  bool _landscape = false;
  bool _autoNextDone = false;
  String _quality = LiveGoSettings.quality.isEmpty ? 'Auto Adaptive' : LiveGoSettings.quality;
  bool _subtitleEnabled = LiveGoSettings.subtitlesEnabled;
  String _subtitleLanguage = 'Auto';
  String _audioTrack = 'Source';
  double _speed = 1.0;
  Duration _lastProgressSaved = Duration.zero;
  DateTime _lastTapLeft = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTapRight = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _openStream();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _PlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream.url != widget.stream.url) _openStream();
  }

  Future<void> _openStream() async {
    await _controller?.dispose();
    _controller = null;
    _error = '';
    _buffering = true;
    _autoNextDone = false;
    if (mounted) setState(() {});

    if (widget.stream.url.isEmpty) {
      _error = 'Stream belum tersedia dari API.';
      _buffering = false;
      if (mounted) setState(() {});
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.stream.url),
        httpHeaders: widget.stream.headers.isEmpty ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'} : widget.stream.headers,
      );
      _controller = controller;
      controller.addListener(_listen);
      await controller.initialize();
      final saved = LiveGoLocalStore.progressFor(widget.item);
      if (saved != null && saved.episode == widget.episode && saved.position.inSeconds > 5) {
        await controller.seekTo(saved.position);
      }
      await controller.play();
      if (mounted) setState(() => _buffering = false);
    } catch (e) {
      _error = '$e';
      _buffering = false;
      if (mounted) setState(() {});
    }
  }

  void _listen() {
    final c = _controller;
    if (!mounted || c == null) return;
    final value = c.value;
    if (_buffering != value.isBuffering) setState(() => _buffering = value.isBuffering);
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
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted && _controls) setState(() => _controls = false);
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
    _showControls();
  }

  Future<void> _toggleLandscape() async {
    _landscape = !_landscape;
    if (_landscape) {
      _fitCover = false;
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    if (mounted) setState(() {});
    _showControls();
  }

  Future<void> _togglePortraitFull() async {
    _fitCover = !_fitCover;
    if (_fitCover) {
      _landscape = false;
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    if (mounted) setState(() {});
    _showControls();
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
            : (subtitles.isEmpty ? 'Tidak tersedia' : _subtitleLanguage);
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
                _SheetRow(
                  title: 'Auto Next',
                  value: LiveGoSettings.autoNextEnabled ? 'Aktif' : 'Mati',
                  onTap: () {
                    setState(() => LiveGoSettings.autoNextEnabled = !LiveGoSettings.autoNextEnabled);
                    Navigator.pop(context);
                    _openPlayerSettings();
                  },
                ),
                _SheetRow(title: 'Kecepatan Pemutaran', value: '${_speed.toStringAsFixed(1)}x', onTap: _speedMenu),
                _SheetRow(title: 'Audio Track', value: _audioTrack, onTap: _audioMenu),
                _SheetRow(title: 'Widevine DRM', value: LiveGoSettings.drmMode, onTap: _drmMenu),
                _SheetRow(title: 'Pengaturan Subtitle', value: subtitleText, onTap: _subtitleMenu),
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
                  'Stream API saat ini HLS adaptive. Pilihan ini disimpan sebagai preferensi user; kualitas manual real akan aktif kalau provider mengirim pilihan stream berbeda.',
                  style: TextStyle(color: Colors.white60, height: 1.35),
                ),
              ),
              _QualityChip(label: 'Auto Adaptive', current: _quality, onPick: (v) => Navigator.pop(context, v)),
              _QualityChip(label: 'Hemat Data', current: _quality, onPick: (v) => Navigator.pop(context, v)),
              _QualityChip(label: 'Normal', current: _quality, onPick: (v) => Navigator.pop(context, v)),
              _QualityChip(label: 'Kualitas Tinggi', current: _quality, onPick: (v) => Navigator.pop(context, v)),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() => _quality = picked);
      LiveGoSettings.quality = picked;
    }
    _showControls();
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
      setState(() {
        if (picked == 'OFF') {
          _subtitleEnabled = false;
          LiveGoSettings.subtitlesEnabled = false;
        } else {
          _subtitleEnabled = true;
          _subtitleLanguage = picked;
          LiveGoSettings.subtitlesEnabled = true;
        }
      });
    }
    _showControls();
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
              const Text('Pilih Audio', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _OptionTile(label: 'Source / Default', selected: _audioTrack == 'Source', onTap: () => Navigator.pop(context, 'Source')),
              _OptionTile(label: 'Mute', selected: _muted, onTap: () => Navigator.pop(context, 'Mute')),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Audio multi-track real akan aktif kalau provider mengirim audio track terpisah.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      if (picked == 'Mute') {
        _muted = true;
        await _controller?.setVolume(0);
      } else {
        _audioTrack = picked;
        _muted = false;
        await _controller?.setVolume(1);
      }
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
    _controller?.removeListener(_listen);
    _controller?.dispose();
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
      canPop: !_controls,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_controls) {
          setState(() => _controls = false);
          _timer?.cancel();
        }
      },
      child: GestureDetector(
        onTap: _toggleControls,
        child: LayoutBuilder(
          builder: (context, box) {
            final screenW = box.maxWidth;
            final screenH = box.maxHeight;
            final videoRatio = ready && c.value.aspectRatio > 0 ? c.value.aspectRatio : 9 / 16;
            final isPortraitVideo = videoRatio < 1.0;

            // Mode container LiveGO:
            // - Normal portrait video: 75-80% tinggi layar, rasio asli tetap aman.
            // - Normal landscape video: lebar dominan, tidak dipaksa gepeng.
            // - Full portrait / landscape: seluruh layar, controls ikut lebar layar.
            double playerW;
            double playerH;
            if (_fitCover || _landscape) {
              playerW = screenW;
              playerH = screenH;
            } else if (isPortraitVideo) {
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
              final maxH = screenH * 0.58;
              if (playerH > maxH) {
                playerH = maxH;
                playerW = playerH * videoRatio;
              }
            }

            final BoxFit videoFit = _fitCover
                ? BoxFit.cover
                : (_landscape && isPortraitVideo ? BoxFit.fitHeight : BoxFit.contain);

            return Center(
              child: SizedBox(
                width: playerW,
                height: playerH,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (ready)
                        Center(
                          child: FittedBox(
                            fit: videoFit,
                            child: SizedBox(
                              width: c.value.size.width,
                              height: c.value.size.height,
                              child: VideoPlayer(c),
                            ),
                          ),
                        )
                      else if (image.isNotEmpty)
                        Image.network(image, fit: BoxFit.cover)
                      else
                        const ColoredBox(color: Color(0xFF101010)),
                      if (!ready) const DecoratedBox(decoration: BoxDecoration(color: Color(0x88000000))),
                      Row(
                children: [
                  Expanded(child: GestureDetector(onTap: () => _doubleTapSeek(false), onLongPressStart: (_) => _holdSpeed(true), onLongPressEnd: (_) => _holdSpeed(false), child: const SizedBox.expand())),
                  Expanded(child: GestureDetector(onTap: _togglePlay, child: const SizedBox.expand())),
                  Expanded(child: GestureDetector(onTap: () => _doubleTapSeek(true), onLongPressStart: (_) => _holdSpeed(true), onLongPressEnd: (_) => _holdSpeed(false), child: const SizedBox.expand())),
                ],
              ),
              if (widget.loading || _buffering) const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
              if (_error.isNotEmpty) Center(child: Padding(padding: const EdgeInsets.all(18), child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)))),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                top: _controls ? 0 : -95,
                left: 0,
                right: 0,
                child: _TopOverlay(title: '${widget.item.title} - Eps ${widget.episode}', onBack: widget.onBack),
              ),
              if (_controls)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CenterButton(icon: Icons.skip_previous_rounded, enabled: widget.episode > 1, onTap: () => widget.onEpisode(widget.episode - 1)),
                      const SizedBox(width: 30),
                      _MainPlayButton(playing: ready && c.value.isPlaying, onTap: _togglePlay),
                      const SizedBox(width: 30),
                      _CenterButton(icon: Icons.skip_next_rounded, enabled: widget.episode < widget.item.episodes, onTap: () => widget.onEpisode(widget.episode + 1)),
                    ],
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                bottom: _controls ? 0 : -160,
                left: 0,
                right: 0,
                child: _BottomOverlay(
                  controller: c,
                  episode: widget.episode,
                  total: widget.item.episodes,
                  quality: _quality == 'Auto' ? 'Auto Adaptive' : _quality,
                  muted: _muted,
                  fitCover: _fitCover,
                  landscape: _landscape,
                  onEpisodes: _showEpisodes,
                  onDownload: () => LiveGoLocalStore.toggleDownload(widget.item),
                  onSettings: _openPlayerSettings,
                  onQuality: _qualityMenu,
                  onRotate: _toggleLandscape,
                  onFit: _togglePortraitFull,
                ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
          Text('${item.source} • Episode $episode / ${item.episodes} • ${item.category}', style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w800)),
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
  const _TopOverlay({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.only(top: 28, left: 8, right: 12),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.86), Colors.transparent])),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        ],
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
  final VoidCallback onRotate;
  final VoidCallback onFit;
  const _BottomOverlay({required this.controller, required this.episode, required this.total, required this.quality, required this.muted, required this.fitCover, required this.landscape, required this.onEpisodes, required this.onDownload, required this.onSettings, required this.onQuality, required this.onRotate, required this.onFit});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.94), Colors.transparent])),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c != null && c.value.isInitialized)
            Row(
              children: [
                Text(_fmt(c.value.position), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                Expanded(
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    colors: const VideoProgressColors(playedColor: AppTheme.cyan, bufferedColor: Colors.white30, backgroundColor: Colors.white12),
                  ),
                ),
                Text(_fmt(c.value.duration), style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Shortcut(icon: Icons.menu_rounded, label: 'Eps', onTap: onEpisodes),
              const SizedBox(width: 8),
              _Shortcut(icon: Icons.download_rounded, label: 'Unduh', onTap: onDownload),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSettings, icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18)),
                      GestureDetector(onTap: onQuality, child: Text(quality, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
                      GestureDetector(onTap: onRotate, child: Icon(Icons.screen_rotation_rounded, color: landscape ? AppTheme.cyan : Colors.white, size: 18)),
                      GestureDetector(onTap: onFit, child: Icon(fitCover ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: fitCover ? AppTheme.cyan : Colors.white, size: 20)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
        child: Row(children: [Icon(icon, color: Colors.white, size: 15), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))]),
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
            selected ? '▶  $label' : label,
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
    final selected = current == label || (label == 'Auto Adaptive' && current == 'Auto');
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
