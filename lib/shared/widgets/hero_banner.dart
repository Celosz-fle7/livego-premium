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
      padding: EdgeInsets.all(tv ? 6 : 10),
      decoration: BoxDecoration(
        gradient: tv
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A1321), Color(0xFF050A13)],
              )
            : null,
        color: tv ? null : AppTheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(tv ? 22 : 34),
        border: Border.all(color: tv ? const Color(0xFF1D3550) : const Color(0xFF26415D)),
        boxShadow: tv
            ? [
                BoxShadow(color: AppTheme.cyan.withOpacity(0.08), blurRadius: 22, spreadRadius: 1),
                const BoxShadow(color: Colors.black87, blurRadius: 18),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tv ? 18 : 26),
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
                    colors: [Color(0x2239D9FF), Color(0x00000000)],
                  ),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF2040810), Color(0x8A0A1321), Color(0xDA030711)],
                ),
              ),
            ),
            Positioned(
              left: tv ? 20 : 28,
              bottom: tv ? 14 : 32,
              right: tv ? 130 : 128,
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
                      fontSize: tv ? 21 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: tv ? 5 : 10),
                  Text(
                    item.description,
                    maxLines: tv ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: tv ? 11.5 : 13),
                  ),
                ],
              ),
            ),
            Positioned(
              right: tv ? 18 : 24,
              bottom: tv ? 16 : 40,
              child: Container(
                padding: EdgeInsets.all(tv ? 2.5 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  border: tv ? Border.all(color: AppTheme.cyan.withOpacity(0.18)) : null,
                  boxShadow: tv ? [BoxShadow(color: AppTheme.purple.withOpacity(0.18), blurRadius: 18)] : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LiveGoCachedImage(
                  url: item.posterUrl,
                  width: tv ? 68 : 92,
                  height: tv ? 96 : 132,
                  fit: BoxFit.cover,
                  role: LiveGoImageRole.poster,
                  tv: tv,
                  ),
                ),
              ),
            ),
            Positioned(left: tv ? 18 : 24, top: tv ? 14 : 20, child: _AccentLine(tv: tv)),
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
        color: const Color(0xFF0F172A).withOpacity(0.8),
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
        color: const Color(0xFF07101D).withOpacity(0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Color(0xFFD6E6F5), fontWeight: FontWeight.w900, fontSize: 9.5),
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
      width: tv ? 52 : 76,
      height: tv ? 4 : 6,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
