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
import '../../models/livego_episode.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../../services/image/image_quality_config.dart';
import '../../services/player/player_preferences.dart';

class TvPlayerScreen extends StatefulWidget {
  final ContentItem item;
  const TvPlayerScreen({super.key, required this.item});

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  final FocusNode _remoteNode = FocusNode(skipTraversal: true, debugLabel: 'tv-player-remote');

  VideoPlayerController? _controller;
  ContentItem? _detail;
  StreamInfo _streamInfo = StreamInfo.empty;
  String _url = '';
  String _error = '';
  bool _loading = true;
  bool _controlsVisible = true;
  bool _episodePanelOpen = false;
  bool _qualityPanelOpen = false;
  int _episode = 1;
  int _knownEpisodeCount = 0;
  int _episodeCursor = 0;
  int _qualityCursor = 0;
  double _speed = 1.0;
  String _audioTrack = 'Source';
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _episode = LiveGoLocalStore.continueEpisode(widget.item);
    _episodeCursor = (_episode - 1).clamp(0, 119).toInt();
    LiveGoLocalStore.addHistory(widget.item);
    _loadPreferences();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _remoteNode.requestFocus());
  }

  Future<void> _loadPreferences() async {
    await PlayerPreferences.load();
    if (!mounted) return;
    _speed = PlayerPreferences.speed;
    _audioTrack = PlayerPreferences.audioTrack;
    await _controller?.setPlaybackSpeed(_speed);
    await _controller?.setVolume(_audioTrack == 'Mute' ? 0 : 1);
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
      _url = '';
      _controlsVisible = true;
    });

    try {
      final requestedEpisode = _episode <= 0 ? 1 : _episode;
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

      final streamFuture = LiveGoCatalog.streamInfo(fastPlayable, chapterId: '$requestedEpisode');
      final detailFuture = LiveGoCatalog.detail(widget.item);

      var stream = await streamFuture.timeout(const Duration(seconds: 8), onTimeout: () => StreamInfo.empty);

      ContentItem detail = widget.item;
      List<LiveGoEpisode> realEpisodes = const <LiveGoEpisode>[];
      try {
        detail = _keepPlayableIdentity(await detailFuture.timeout(const Duration(seconds: 4)));
        realEpisodes = await LiveGoCatalog.episodes(detail).timeout(const Duration(seconds: 5));
        final count = realEpisodes.length > 1 ? realEpisodes.length : detail.episodes;
        if (mounted && count > 1 && count != _knownEpisodeCount) {
          setState(() => _knownEpisodeCount = count);
        }
      } catch (e) {
        debugPrint('LIVEGO TV PLAYER metadata skipped: $e');
      }

      final fallbackTotal = widget.item.episodes > 0
          ? widget.item.episodes
          : (detail.episodes > 0 ? detail.episodes : (stream.totalEpisodes > 1 ? stream.totalEpisodes : 1));
      final safeIndex = requestedEpisode.clamp(1, realEpisodes.isEmpty ? fallbackTotal : realEpisodes.length);
      final episodeId = realEpisodes.isEmpty ? '$safeIndex' : realEpisodes[safeIndex - 1].id;
      final selected = ContentItem(
        id: detail.id.trim().isNotEmpty ? detail.id : widget.item.id,
        title: detail.title.trim().isNotEmpty ? detail.title : widget.item.title,
        source: detail.source.trim().isNotEmpty ? detail.source : widget.item.source,
        category: detail.category.trim().isNotEmpty ? detail.category : widget.item.category,
        description: detail.description.trim().isNotEmpty ? detail.description : widget.item.description,
        posterUrl: detail.posterUrl.trim().isNotEmpty ? detail.posterUrl : widget.item.posterUrl,
        backdropUrl: detail.backdropUrl.trim().isNotEmpty ? detail.backdropUrl : widget.item.backdropUrl,
        rating: detail.rating,
        episodes: realEpisodes.isEmpty ? fallbackTotal : realEpisodes.length,
        updated: detail.updated || widget.item.updated,
        platformSlug: detail.platformSlug.trim().isNotEmpty ? detail.platformSlug : widget.item.platformSlug,
        chapterId: episodeId,
        lang: detail.lang.trim().isNotEmpty ? detail.lang : widget.item.lang,
      );

      if (stream.url.isEmpty) {
        stream = await LiveGoCatalog.streamInfo(selected, chapterId: episodeId)
            .timeout(const Duration(seconds: 8), onTimeout: () => StreamInfo.empty);
      }

      final total = realEpisodes.isNotEmpty
          ? realEpisodes.length
          : (stream.totalEpisodes > selected.episodes ? stream.totalEpisodes : selected.episodes);
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
        chapterId: episodeId,
        lang: selected.lang,
      );

      debugPrint('LIVEGO TV VIDEO API ${playable.platformSlug} id=${playable.id} ep=$episodeId stream=${stream.url.isNotEmpty} qualities=${stream.qualities.length} total=${playable.episodes}');

      await _controller?.dispose();
      _controller = null;
      _detail = playable;
      _streamInfo = stream;
      _url = stream.urlForQuality(PlayerPreferences.quality);
      if (_url.isEmpty) _url = stream.url;
      _episodeCursor = (_episode - 1).clamp(0, (playable.episodes <= 0 ? 1 : playable.episodes) - 1).toInt();

      if (_url.isNotEmpty) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(_url),
          httpHeaders: stream.headers.isEmpty ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'} : stream.headers,
        );
        _controller = controller;
        controller.addListener(() {
          if (!mounted || !controller.value.isInitialized) return;
          final value = controller.value;
          if (value.position.inSeconds % 5 == 0) {
            LiveGoLocalStore.saveProgress(_detail ?? widget.item, _episode, value.position, value.duration);
          }
          final duration = value.duration;
          if (LiveGoSettings.autoNextEnabled && duration.inSeconds > 15 && _episode < (_detail?.episodes ?? widget.item.episodes)) {
            final remaining = duration - value.position;
            if (remaining.inSeconds <= 2 && value.position.inSeconds > 8) {
              LiveGoLocalStore.markEpisodeComplete(_detail ?? widget.item, _episode);
              _episode += 1;
              _load();
            }
          }
        });
        await controller.initialize();
        await controller.setPlaybackSpeed(_speed);
        await controller.setVolume(_audioTrack == 'Mute' ? 0 : 1);
        final saved = LiveGoLocalStore.progressFor(playable);
        if (saved != null && saved.episode == _episode && saved.position.inSeconds > 5) {
          await controller.seekTo(saved.position);
        }
        await controller.play();
        _scheduleHideControls();
      }
    } catch (e) {
      _error = '$e';
    }

    _loading = false;
    if (mounted) setState(() {});
  }

  void _showControls({bool keep = false}) {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    if (!keep) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _episodePanelOpen || _qualityPanelOpen) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    _showControls();
    setState(() {});
  }

  List<String> get _qualityLabels {
    final labels = <String>['Auto'];
    for (final quality in _streamInfo.qualities) {
      if (quality.label.trim().isNotEmpty && !labels.contains(quality.label)) labels.add(quality.label);
    }
    return labels;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause;
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.browserBack;
  }

  bool _isMenuKey(LogicalKeyboardKey key) {
    return key.keyLabel.toLowerCase().contains('menu');
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_episodePanelOpen) return _episodePanelKey(key);
    if (_qualityPanelOpen) return _qualityPanelKey(key);

    if (_isBack(key)) {
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }

    if (_isMenuKey(key)) {
      _openQualityPanel();
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      _toggle();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(const Duration(seconds: 10));
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(const Duration(seconds: -10));
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _showControls(keep: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _openEpisodePanel();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _episodePanelKey(LogicalKeyboardKey key) {
    final total = _episodeTotal;
    if (_isBack(key) || key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _episodePanelOpen = false;
        _controlsVisible = true;
      });
      _scheduleHideControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _episodeCursor = (_episodeCursor - 1).clamp(0, total - 1).toInt());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _episodeCursor = (_episodeCursor + 1).clamp(0, total - 1).toInt());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _episodeCursor = (_episodeCursor + 4).clamp(0, total - 1).toInt());
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _selectEpisode(_episodeCursor + 1);
      setState(() => _episodePanelOpen = false);
      return KeyEventResult.handled;
    }
    if (_isMenuKey(key)) {
      setState(() {
        _episodePanelOpen = false;
        _qualityPanelOpen = true;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _qualityPanelKey(LogicalKeyboardKey key) {
    final labels = _qualityLabels;
    if (_isBack(key) || key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _qualityPanelOpen = false);
      _scheduleHideControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _qualityCursor = (_qualityCursor - 1).clamp(0, labels.length - 1).toInt());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
      setState(() => _qualityCursor = (_qualityCursor + 1).clamp(0, labels.length - 1).toInt());
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _changeQuality(labels[_qualityCursor]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  int get _episodeTotal {
    final item = _detail ?? widget.item;
    final total = _knownEpisodeCount > item.episodes ? _knownEpisodeCount : item.episodes;
    return total.clamp(1, 120).toInt();
  }

  void _openEpisodePanel() {
    final total = _episodeTotal;
    setState(() {
      _episodePanelOpen = true;
      _qualityPanelOpen = false;
      _controlsVisible = true;
      _episodeCursor = (_episode - 1).clamp(0, total - 1).toInt();
    });
    _hideTimer?.cancel();
  }

  void _openQualityPanel() {
    final labels = _qualityLabels;
    final current = labels.indexOf(PlayerPreferences.quality);
    setState(() {
      _qualityPanelOpen = true;
      _episodePanelOpen = false;
      _controlsVisible = true;
      _qualityCursor = current < 0 ? 0 : current;
    });
    _hideTimer?.cancel();
  }

  void _seekRelative(Duration offset) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final target = c.value.position + offset;
    final duration = c.value.duration;
    c.seekTo(target.isNegative ? Duration.zero : (target > duration ? duration : target));
  }

  Future<void> _changeQuality(String label) async {
    await PlayerPreferences.setQuality(label);
    if (!mounted) return;
    setState(() => _qualityPanelOpen = false);
    _load();
  }

  void _selectEpisode(int episode) {
    _episode = episode;
    _episodeCursor = (episode - 1).clamp(0, 119).toInt();
    _load();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _remoteNode.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _detail ?? widget.item;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Focus(
      focusNode: _remoteNode,
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _handleRemoteKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else if (item.backdropUrl.isNotEmpty || item.posterUrl.isNotEmpty)
              LiveGoCachedImage(
                url: item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl,
                fit: BoxFit.cover,
                role: LiveGoImageRole.thumbnail,
                tv: true,
              ),
            Container(color: Colors.black.withOpacity(ready ? 0 : 0.38)),
            if (_loading) const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
            if (!_loading && !ready)
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _error.isNotEmpty ? _error : (_url.isEmpty ? 'Stream belum tersedia' : 'Menyiapkan player...'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            if (_controlsVisible) _PlayerOverlay(item: item, controller: controller, ready: ready, episode: _episode, total: _episodeTotal, speed: _speed, quality: PlayerPreferences.quality, streamOk: _url.isNotEmpty),
            if (_episodePanelOpen) _EpisodePanel(total: _episodeTotal, cursor: _episodeCursor, selected: _episode),
            if (_qualityPanelOpen) _QualityPanel(labels: _qualityLabels, cursor: _qualityCursor, selected: PlayerPreferences.quality),
          ],
        ),
      ),
    );
  }
}

class _PlayerOverlay extends StatelessWidget {
  final ContentItem item;
  final VideoPlayerController? controller;
  final bool ready;
  final int episode;
  final int total;
  final double speed;
  final String quality;
  final bool streamOk;

  const _PlayerOverlay({required this.item, required this.controller, required this.ready, required this.episode, required this.total, required this.speed, required this.quality, required this.streamOk});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent, Colors.black87],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(34, 24, 34, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tv_rounded, color: AppTheme.cyan, size: 24),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900))),
                    Text('Ep $episode/$total  •  $quality  •  ${speed.toStringAsFixed(2)}x', style: const TextStyle(color: AppTheme.cyan, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
                const Spacer(),
                if (ready && controller != null) ...[
                  VideoProgressIndicator(
                    controller!,
                    allowScrubbing: false,
                    colors: const VideoProgressColors(playedColor: AppTheme.cyan, bufferedColor: Colors.white30, backgroundColor: Colors.white12),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Icon(ready && controller!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'OK Play/Pause   ←/→ Seek 10s   ↑ Kontrol   ↓ Episode   Menu Quality   Back Tutup/Keluar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(streamOk ? 'Video API: OK' : 'Video API: belum ada stream', style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodePanel extends StatelessWidget {
  final int total;
  final int cursor;
  final int selected;

  const _EpisodePanel({required this.total, required this.cursor, required this.selected});

  @override
  Widget build(BuildContext context) {
    final count = total > 120 ? 120 : total;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 330,
        margin: const EdgeInsets.only(right: 28),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xEE09111E), borderRadius: BorderRadius.circular(26), border: Border.all(color: AppTheme.cyan.withOpacity(0.45))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Episode', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            SizedBox(
              height: 430,
              child: GridView.builder(
                itemCount: count,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.35),
                itemBuilder: (_, i) {
                  final ep = i + 1;
                  final active = ep == selected;
                  final focused = i == cursor;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.cyan.withOpacity(0.26) : const Color(0xFF111B2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: focused ? AppTheme.cyan : (active ? AppTheme.cyan.withOpacity(0.5) : Colors.white12), width: focused ? 2.5 : 1),
                    ),
                    child: Text('$ep', style: TextStyle(color: active || focused ? Colors.white : Colors.white60, fontWeight: FontWeight.w900)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityPanel extends StatelessWidget {
  final List<String> labels;
  final int cursor;
  final String selected;

  const _QualityPanel({required this.labels, required this.cursor, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(left: 34),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xEE09111E), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.cyan.withOpacity(0.45))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quality', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (var i = 0; i < labels.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: labels[i] == selected ? AppTheme.cyan.withOpacity(0.18) : const Color(0xFF111B2A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: i == cursor ? AppTheme.cyan : Colors.white12, width: i == cursor ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Icon(labels[i] == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: labels[i] == selected || i == cursor ? AppTheme.cyan : Colors.white38, size: 20),
                    const SizedBox(width: 10),
                    Text(labels[i], style: TextStyle(color: labels[i] == selected || i == cursor ? Colors.white : Colors.white60, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
