class _PlayerSurfaceState extends State<_PlayerSurface> {
  VideoPlayerController? _controller;
  Timer? _timer;
  Timer? _autoQualityTimer;
  String _activeUrl = '';
  String _error = '';
  bool _controls = true;
  bool _buffering = true;
  bool _muted = false;
  bool _fitCover = false;
  bool _landscape = false;
  bool _autoNextDone = false;
  String _quality = PlayerPreferences.quality;
  bool _subtitleEnabled = PlayerPreferences.subtitleEnabled;
  String _subtitleLanguage = PlayerPreferences.subtitleLanguage;
  String _audioTrack = PlayerPreferences.audioTrack;
  double _speed = PlayerPreferences.speed;
  Duration _lastProgressSaved = Duration.zero;
  DateTime _lastTapLeft = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTapRight = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _openStream();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoQualityTimer?.cancel();
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
  void didUpdateWidget(covariant _PlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream.url != widget.stream.url) _openStream();
  }

  Future<void> _loadPreferences() async {
    await PlayerPreferences.load();
    if (!mounted) return;
    setState(() {
      _quality = PlayerPreferences.quality;
      _subtitleEnabled = PlayerPreferences.subtitleEnabled;
      _subtitleLanguage = PlayerPreferences.subtitleLanguage;
      _audioTrack = PlayerPreferences.audioTrack;
      _speed = PlayerPreferences.speed;
    });
    await _controller?.setPlaybackSpeed(_speed);
    await _controller?.setVolume(_audioTrack == 'Mute' ? 0 : 1);
  }

  Future<void> _openStream() async {
    _autoQualityTimer?.cancel();
    await _controller?.dispose();
    _controller = null;
    _error = '';
    _buffering = true;
    _autoNextDone = false;
    _activeUrl = '';
    if (mounted) setState(() {});
    final url = _resolvedInitialUrl();
    if (url.isEmpty) { _error = 'Stream belum tersedia.'; _buffering = false; if (mounted) setState(() {}); return; }
    await _openResolvedUrl(url, resume: true, autoplay: true);
    _scheduleAutoQualityUpgrade();
  }

  String _resolvedInitialUrl() => _quality.toLowerCase() == 'auto' ? widget.stream.autoStartUrl : widget.stream.urlForQuality(_quality);

  Future<void> _openResolvedUrl(String url, {required bool resume, required bool autoplay}) async {
    try {
      _activeUrl = url;
      final old = _controller;
      old?.removeListener(_listen);
      await old?.dispose();
      final controller = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: widget.stream.headers.isEmpty ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'} : widget.stream.headers);
      _controller = controller;
      controller.addListener(_listen);
      await controller.initialize();
      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(_audioTrack == 'Mute' ? 0 : 1);
      if (resume) {
        final saved = LiveGoLocalStore.progressFor(widget.item);
        if (saved != null && saved.episode == widget.episode && saved.position.inSeconds > 5) await controller.seekTo(saved.position);
      }
      if (autoplay) await controller.play();
      if (mounted) setState(() => _buffering = false);
    } catch (e) { _error = '$e'; _buffering = false; if (mounted) setState(() {}); }
  }

  void _scheduleAutoQualityUpgrade() {
    _autoQualityTimer?.cancel();
    if (_quality.toLowerCase() != 'auto') return;
    final best = widget.stream.autoBestUrl;
    if (best.isEmpty || best == _activeUrl) return;
    _autoQualityTimer = Timer(const Duration(seconds: 10), () async {
      final c = _controller;
      if (!mounted || c == null || !c.value.isInitialized || _quality.toLowerCase() != 'auto') return;
      if (c.value.position.inSeconds < 5 || c.value.isBuffering) return;
      final pos = c.value.position;
      final wasPlaying = c.value.isPlaying;
      setState(() => _buffering = true);
      await _openResolvedUrl(best, resume: false, autoplay: wasPlaying);
      final next = _controller;
      if (next != null && next.value.isInitialized) { await next.seekTo(pos); if (wasPlaying) await next.play(); }
      if (mounted) setState(() => _buffering = false);
    });
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
    _timer = Timer(const Duration(seconds: 12), () {
      final controller = _controller;
      final keepVisible = controller != null && controller.value.isInitialized && !controller.value.isPlaying;
      if (mounted && _controls && !keepVisible) setState(() => _controls = false);
    });
  }

  void _showControls() { setState(() => _controls = true); _startTimer(); }
  void _toggleControls() { setState(() => _controls = !_controls); if (_controls) _startTimer(); }
  void _togglePlay() { final c = _controller; if (c == null || !c.value.isInitialized) return; c.value.isPlaying ? c.pause() : c.play(); _showControls(); setState(() {}); }
  
  Future<void> _seek(int seconds) async { final c = _controller; if (c == null || !c.value.isInitialized) return; await c.seekTo(c.value.position + Duration(seconds: seconds)); _showControls(); }
  void _doubleTapSeek(bool right) {
    final now = DateTime.now();
    final last = right ? _lastTapRight : _lastTapLeft;
    if (now.difference(last).inMilliseconds < 320) _seek(right ? 10 : -10);
    if (right) _lastTapRight = now; else _lastTapLeft = now;
  }

  Future<void> _holdSpeed(bool fast) async { final c = _controller; if (c == null) return; _speed = fast ? 2.0 : 1.0; await c.setPlaybackSpeed(_speed); if (mounted) setState(() {}); }
  
  Future<void> _toggleLandscape() async {
    _landscape = !_landscape;
    if (_landscape) { _fitCover = false; await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]); }
    else { await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); }
    if (mounted) setState(() {}); _showControls();
  }

  Future<void> _togglePortraitFull() async {
    _fitCover = !_fitCover;
    if (_fitCover) { _landscape = false; await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); }
    else { await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); }
    if (mounted) setState(() {}); _showControls();
  }

  Future<void> _downloadCurrentEpisode() async {
    _showControls();
    if (widget.stream.url.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream belum tersedia.'))); return; }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download dimulai...')));
    final result = await DownloadService.enqueue(item: widget.item, episode: widget.episode, stream: widget.stream, quality: _quality);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.status == DownloadStatus.completed ? 'Download selesai.' : 'Download error')));
  }

  void _openPlayerSettings() {
    _showControls();
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0D1117), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pengaturan Player', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 14), _SheetRow(title: 'Kualitas', value: _quality, onTap: _qualityMenu), _SheetRow(title: 'Kecepatan', value: '${_speed.toStringAsFixed(1)}x', onTap: _speedMenu), _SheetRow(title: 'Audio', value: _audioTrack, onTap: _audioMenu), _SheetRow(title: 'Subtitle', value: !_subtitleEnabled ? 'Mati' : _subtitleLanguage, onTap: _subtitleMenu)]))));
  }

  Future<void> _qualityMenu() async { /* Tambahkan fungsi menu kualitas Anda */ }
  Future<void> _subtitleMenu() async { /* Tambahkan fungsi menu subtitle Anda */ }
  Future<void> _audioMenu() async { /* Tambahkan fungsi menu audio Anda */ }
  void _speedMenu() async { /* Tambahkan fungsi speed Anda */ }
  void _showEpisodes() { /* Tambahkan fungsi show episode Anda */ }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final image = widget.item.backdropUrl.isNotEmpty ? widget.item.backdropUrl : widget.item.posterUrl;

    return PopScope(
      canPop: !_controls,
      onPopInvoked: (didPop) { if (didPop) return; if (_controls) { setState(() => _controls = false); _timer?.cancel(); } },
      child: GestureDetector(
        onTap: _toggleControls,
        child: LayoutBuilder(
          builder: (context, box) {
            final videoRatio = ready && c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
            final BoxFit videoFit = _fitCover ? BoxFit.cover : BoxFit.contain;

            return Center(
              child: Container(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: _fitCover || _landscape ? (box.maxWidth / box.maxHeight) : videoRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (ready)
                        FittedBox(
                          fit: videoFit,
                          child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
                        )
                      else if (image.isNotEmpty)
                        LiveGoCachedImage(url: image, fit: BoxFit.cover, role: LiveGoImageRole.thumbnail)
                      else
                        const ColoredBox(color: Color(0xFF101010)),
                      
                      if (!ready) const DecoratedBox(decoration: BoxDecoration(color: Color(0x88000000))),
                      
                      Row(
                        children: [
                          Expanded(child: GestureDetector(onTap: () => _doubleTapSeek(false), child: const SizedBox.expand())),
                          Expanded(child: GestureDetector(onTap: _togglePlay, child: const SizedBox.expand())),
                          Expanded(child: GestureDetector(onTap: () => _doubleTapSeek(true), child: const SizedBox.expand())),
                        ],
                      ),
                      
                      if (widget.loading || _buffering) const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
                      
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
                        bottom: _controls ? 22 : -190,
                        left: 0,
                        right: 0,
                        child: _BottomOverlay(
                          controller: c, episode: widget.episode, total: widget.item.episodes, quality: _quality, muted: _muted,
                          fitCover: _fitCover, landscape: _landscape, onEpisodes: _showEpisodes, onDownload: _downloadCurrentEpisode,
                          onSettings: _openPlayerSettings, onQuality: _qualityMenu, onRotate: _toggleLandscape, onFit: _togglePortraitFull,
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
