import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/app_theme.dart';
import '../../services/image/image_quality_config.dart';

class LiveGoImageCacheManager {
  static const key = 'livegoPosterImageCache';

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

    if (widget.borderRadius == null) return image;
    return ClipRRect(borderRadius: widget.borderRadius!, child: image);
  }

  void _scheduleHighQualityLoad() {
    if (!widget.progressive) {
      _loadHighQuality = true;
      return;
    }

    final delayMs = ImageQualityConfig.progressiveDelayMsFor(widget.role);
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
    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || uri.host.isEmpty) return value;
      return uri.replace(queryParameters: const {}).toString();
    } catch (_) {
      return value;
    }
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
