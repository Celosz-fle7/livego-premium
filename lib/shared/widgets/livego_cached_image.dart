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
      maxNrOfCacheObjects: 1800,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

class LiveGoCachedImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final LiveGoImageRole role;
  final bool tv;

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
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url.trim();
    final image = cleanUrl.isEmpty
        ? _fallback()
        : CachedNetworkImage(
            imageUrl: cleanUrl,
            cacheManager: LiveGoImageCacheManager.instance,
            cacheKey: _stableCacheKey(cleanUrl),
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 120),
            fadeOutDuration: const Duration(milliseconds: 80),
            memCacheWidth: _decodeWidth(context),
            maxWidthDiskCache: _decodeWidth(context),
            placeholder: (_, __) => placeholder ?? _placeholder(),
            errorWidget: (_, __, ___) => errorWidget ?? _fallback(),
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
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

  int? _decodeWidth(BuildContext context) {
    final configured = ImageQualityConfig.widthFor(role: role, tv: tv);
    final logicalWidth = width;
    if (logicalWidth == null || logicalWidth <= 0 || logicalWidth == double.infinity) {
      return configured.clamp(ImageQualityConfig.minDecodeWidth, ImageQualityConfig.maxDecodeWidth);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.5);
    final px = (logicalWidth * dpr).round();
    return px.clamp(
      ImageQualityConfig.minDecodeWidth,
      configured.clamp(ImageQualityConfig.minDecodeWidth, ImageQualityConfig.maxDecodeWidth),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
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
      width: width,
      height: height,
      color: AppTheme.surface2,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
    );
  }
}
