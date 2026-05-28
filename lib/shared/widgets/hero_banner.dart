import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/content_item.dart';

class HeroBanner extends StatelessWidget {
  final ContentItem item;
  final bool tv;
  const HeroBanner({super.key, required this.item, this.tv = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tv ? 245 : 335,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF26415D)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SafeNetworkImage(url: item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl),
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
              left: tv ? 36 : 28,
              bottom: tv ? 36 : 32,
              right: tv ? 260 : 128,
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
                      fontSize: tv ? 34 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.description,
                    maxLines: tv ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: tv ? 15 : 13),
                  ),
                ],
              ),
            ),
            Positioned(
              right: tv ? 44 : 24,
              bottom: tv ? 32 : 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: tv ? 125 : 92,
                  height: tv ? 170 : 132,
                  child: _SafeNetworkImage(url: item.posterUrl),
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


class _SafeNetworkImage extends StatelessWidget {
  final String url;
  const _SafeNetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFF101826),
        alignment: Alignment.center,
        child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 46),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 720,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF101826),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 42),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFF101826),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan),
          ),
        );
      },
    );
  }
}
