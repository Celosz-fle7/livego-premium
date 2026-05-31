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
      height: tv ? 188 : 335,
      padding: EdgeInsets.all(tv ? 8 : 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(tv ? 24 : 34),
        border: Border.all(color: const Color(0xFF26415D)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tv ? 20 : 26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LiveGoCachedImage(url: item.backdropUrl, fit: BoxFit.cover, role: LiveGoImageRole.banner, tv: tv),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xDD050913), Color(0x66050913), Color(0xCC050913)],
                ),
              ),
            ),
            Positioned(
              left: tv ? 28 : 28,
              bottom: tv ? 22 : 32,
              right: tv ? 202 : 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourcePill(text: item.source),
                  SizedBox(height: tv ? 9 : 13),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tv ? 25 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: tv ? 6 : 10),
                  Text(
                    item.description,
                    maxLines: tv ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: tv ? 12.5 : 13),
                  ),
                ],
              ),
            ),
            Positioned(
              right: tv ? 30 : 24,
              bottom: tv ? 22 : 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LiveGoCachedImage(
                  url: item.posterUrl,
                  width: tv ? 88 : 92,
                  height: tv ? 124 : 132,
                  fit: BoxFit.cover,
                  role: LiveGoImageRole.poster,
                  tv: tv,
                ),
              ),
            ),
            Positioned(left: tv ? 22 : 24, top: tv ? 18 : 20, child: _AccentLine(tv: tv)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.5)),
      ),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }
}

class _AccentLine extends StatelessWidget {
  final bool tv;
  const _AccentLine({this.tv = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tv ? 70 : 76,
      height: tv ? 5 : 6,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
