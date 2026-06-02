import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import 'livego_cached_image.dart';
import '../../services/image/image_quality_config.dart';

class HeroBanner extends StatelessWidget {
  final ContentItem item;
  final bool tv;
  const HeroBanner({super.key, required this.item, this.tv = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tv ? double.infinity : 335,
      padding: EdgeInsets.all(tv ? 7 : 10),
      decoration: BoxDecoration(
        gradient: tv
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.surface2, AppTheme.bgDeep],
              )
            : null,
        color: tv ? null : AppTheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(tv ? 24 : 34),
        border: Border.all(color: tv ? AppTheme.borderSoft.withOpacity(0.92) : AppTheme.borderBright.withOpacity(0.32)),
        boxShadow: tv
            ? [
                BoxShadow(color: AppTheme.cyan.withOpacity(0.055), blurRadius: 18),
                const BoxShadow(color: Colors.black87, blurRadius: 15),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tv ? 20 : 26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LiveGoCachedImage(url: item.backdropUrl, fit: BoxFit.cover, role: LiveGoImageRole.banner, tv: tv),
            if (tv)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.64, -0.22),
                    radius: 0.72,
                    colors: [Color(0x4058A6FF), Color(0x12E6F6FF), Color(0x00000000)],
                    stops: [0.0, 0.38, 1.0],
                  ),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF2010409), Color(0x8A071326), Color(0xDE010409)],
                ),
              ),
            ),
            Positioned(
              left: tv ? 24 : 28,
              bottom: tv ? 18 : 32,
              right: tv ? 138 : 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tv)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SourcePill(text: item.source),
                        const SizedBox(width: 8),
                        _MiniInfo(text: '${item.episodes} EP'),
                        const SizedBox(width: 6),
                        _MiniInfo(text: item.rating.toStringAsFixed(1)),
                      ],
                    )
                  else
                    _SourcePill(text: item.source),
                  SizedBox(height: tv ? 8 : 13),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tv ? 22 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: tv ? 5 : 10),
                  Text(
                    item.description,
                    maxLines: tv ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: tv ? 12.0 : 13, height: 1.25),
                  ),
                ],
              ),
            ),
            Positioned(
              right: tv ? 22 : 24,
              bottom: tv ? 18 : 40,
              child: Container(
                padding: EdgeInsets.all(tv ? 2.5 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: tv ? Border.all(color: AppTheme.cyan.withOpacity(0.20)) : null,
                  boxShadow: tv ? [BoxShadow(color: AppTheme.purple.withOpacity(0.14), blurRadius: 14)] : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tv ? 17 : 16),
                  child: LiveGoCachedImage(
                  url: item.posterUrl,
                  width: tv ? 76 : 92,
                  height: tv ? 106 : 132,
                  fit: BoxFit.cover,
                  role: LiveGoImageRole.poster,
                  tv: tv,
                  ),
                ),
              ),
            ),
            Positioned(left: tv ? 22 : 24, top: tv ? 16 : 20, child: _AccentLine(tv: tv)),
          ],
        ),
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final String text;
  const _SourcePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.42)),
      ),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String text;
  const _MiniInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: AppTheme.whiteGlow, fontWeight: FontWeight.w900, fontSize: 9.5),
      ),
    );
  }
}

class _AccentLine extends StatelessWidget {
  final bool tv;
  const _AccentLine({this.tv = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tv ? 58 : 76,
      height: tv ? 3.5 : 6,
      decoration: BoxDecoration(
        gradient: AppTheme.activeGradient,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
