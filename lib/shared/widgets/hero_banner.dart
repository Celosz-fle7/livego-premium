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
      height: tv ? 218 : 335,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(tv ? 28 : 34),
        border: Border.all(color: const Color(0xFF26415D)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tv ? 22 : 26),
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
              left: tv ? 32 : 28,
              bottom: tv ? 30 : 32,
              right: tv ? 230 : 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourcePill(text: item.source),
                  const SizedBox(height: 13),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tv ? 29 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.description,
                    maxLines: tv ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: tv ? 13.5 : 13),
                  ),
                ],
              ),
            ),
            Positioned(
              right: tv ? 36 : 24,
              bottom: tv ? 26 : 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LiveGoCachedImage(
                  url: item.posterUrl,
                  width: tv ? 104 : 92,
                  height: tv ? 146 : 132,
                  fit: BoxFit.cover,
                  role: LiveGoImageRole.poster,
                  tv: tv,
                ),
              ),
            ),
            const Positioned(left: 24, top: 20, child: _AccentLine()),
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
  const _AccentLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 6,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
