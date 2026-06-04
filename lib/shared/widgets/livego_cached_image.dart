import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/app_theme.dart';
import '../../services/image/image_quality_config.dart';

class LiveGoImageCacheManager {
  static const key = 'livegoPosterImageCacheV2';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 2400,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

class LiveGoCachedImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final LiveGoImageRole role;
  final bool tv;
  final bool progressive;

  const LiveGoCachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.role = LiveGoImageRole.poster,
    this.tv = false,
    this.progressive = true,
  });

  @override
  State<LiveGoCachedImage> createState() => _LiveGoCachedImageState();
}

class _LiveGoCachedImageState extends State<LiveGoCachedImage> {
  Timer? _highQualityTimer;
  bool _loadHighQuality = false;

  @override
  void initState() {
    super.initState();
    _scheduleHighQualityLoad();
  }

  @override
  void didUpdateWidget(covariant LiveGoCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.role != widget.role ||
        oldWidget.tv != widget.tv ||
        oldWidget.progressive != widget.progressive) {
      _highQualityTimer?.cancel();
      _loadHighQuality = false;
      _scheduleHighQualityLoad();
    }
  }

  @override
  void dispose() {
    _highQualityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = widget.url.trim();
    final image = cleanUrl.isEmpty
        ? _fallback()
        : widget.progressive
            ? _progressiveImage(context, cleanUrl)
            : _networkImage(
                context,
                cleanUrl,
                decodeWidth: _decodeWidth(context),
                cacheSuffix: 'full',
                showPlaceholder: true,
              );

    final body = widget.borderRadius == null
        ? image
        : ClipRRect(borderRadius: widget.borderRadius!, child: image);
    return RepaintBoundary(child: body);
  }

  void _scheduleHighQualityLoad() {
    if (!widget.progressive) {
      _loadHighQuality = true;
      return;
    }

    final baseDelayMs = ImageQualityConfig.progressiveDelayMsFor(widget.role);
    // TV remote focus must stay responsive. Let low-res posters settle first,
    // then upgrade quality a little later so image decoding does not fight
    // rapid UP/DOWN/LEFT/RIGHT focus moves.
    final jitter = widget.tv ? _tvDecodeJitterMs(widget.url, widget.role) : 0;
    final delayMs = widget.tv ? baseDelayMs + 280 + jitter : baseDelayMs;
    _highQualityTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _loadHighQuality = true);
    });
  }

  Widget _progressiveImage(BuildContext context, String cleanUrl) {
    final lowWidth = _decodeWidth(
      context,
      preferredWidth: ImageQualityConfig.lowWidthFor(
        role: widget.role,
        tv: widget.tv,
      ),
    );
    final highWidth = _decodeWidth(context);

    if (lowWidth == highWidth) {
      return _networkImage(
        context,
        cleanUrl,
        decodeWidth: highWidth,
        cacheSuffix: 'full',
        showPlaceholder: true,
        fadeInDuration: const Duration(milliseconds: 90),
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        _networkImage(
          context,
          cleanUrl,
          decodeWidth: lowWidth,
          cacheSuffix: 'low-$lowWidth',
          showPlaceholder: true,
          fadeInDuration: const Duration(milliseconds: 90),
        ),
        if (_loadHighQuality)
          _networkImage(
            context,
            cleanUrl,
            decodeWidth: highWidth,
            cacheSuffix: 'full',
            showPlaceholder: false,
            fadeInDuration: const Duration(milliseconds: 180),
          ),
      ],
    );
  }

  Widget _networkImage(
    BuildContext context,
    String cleanUrl, {
    required int? decodeWidth,
    required String cacheSuffix,
    required bool showPlaceholder,
    Duration fadeInDuration = const Duration(milliseconds: 120),
  }) {
    return CachedNetworkImage(
      imageUrl: cleanUrl,
      cacheManager: LiveGoImageCacheManager.instance,
      cacheKey: '${_stableCacheKey(cleanUrl)}::$cacheSuffix',
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: const Duration(milliseconds: 80),
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: decodeWidth,
      placeholder: showPlaceholder
          ? (_, __) => widget.placeholder ?? _placeholder()
          : null,
      errorWidget: (_, __, ___) => widget.errorWidget ?? _fallback(),
    );
  }

  String _stableCacheKey(String value) {
    final clean = value.trim();
    try {
      final uri = Uri.parse(clean);
      if (!uri.hasScheme || uri.host.isEmpty) return clean;

      // Dobda image proxy URLs commonly differ in query parameters only.
      // The old key removed query params, so many different posters could share
      // one cache entry and appear as the same image in Home/grid.
      // Keep the full URL for correctness, but drop fragments because they do not
      // identify the network resource.
      return uri.removeFragment().toString();
    } catch (_) {
      return clean;
    }
  }

  int _tvDecodeJitterMs(String url, LiveGoImageRole role) {
    final max = ImageQualityConfig.tvProgressiveJitterMsFor(role);
    if (max <= 0) return 0;
    var hash = 0;
    for (var i = 0; i < url.length; i++) {
      hash = (hash + url.codeUnitAt(i) * (i + 1)) & 0x7fffffff;
    }
    return hash % max;
  }

  int? _decodeWidth(BuildContext context, {int? preferredWidth}) {
    final configured = preferredWidth ??
        ImageQualityConfig.widthFor(role: widget.role, tv: widget.tv);
    final maxConfigured = _clampInt(
      configured,
      ImageQualityConfig.minDecodeWidth,
      ImageQualityConfig.maxDecodeWidth,
    );
    final logicalWidth = widget.width;

    if (logicalWidth == null || logicalWidth <= 0 || logicalWidth == double.infinity) {
      return maxConfigured;
    }

    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.5).toDouble();
    final px = (logicalWidth * dpr).round();
    return _clampInt(px, ImageQualityConfig.minDecodeWidth, maxConfigured);
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Widget _placeholder() {
    if (widget.tv) {
      // A grid full of animated spinners can steal frames from TV remote focus.
      // Use a static placeholder on TV; the low-res image will replace it fast.
      return Container(
        width: widget.width,
        height: widget.height,
        color: AppTheme.surface2,
        alignment: Alignment.center,
        child: Icon(
          widget.role == LiveGoImageRole.banner ? Icons.image_rounded : Icons.movie_rounded,
          color: Colors.white24,
          size: widget.role == LiveGoImageRole.banner ? 42 : 30,
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.surface2,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.surface2,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
    );
  }
}
