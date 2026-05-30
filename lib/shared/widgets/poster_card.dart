import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';
import 'livego_cached_image.dart';
import '../../services/image/image_quality_config.dart';

class PosterCard extends StatelessWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final bool tv;

  const PosterCard({super.key, required this.item, this.onTap, this.tv = false});

  @override
  Widget build(BuildContext context) {
    final width = tv ? 158.0 : 150.0;
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final progress = LiveGoLocalStore.progressFor(item)?.ratio ?? 0;
        final fav = LiveGoLocalStore.isFavorite(item);
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        item.posterUrl.isEmpty
                            ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 46))
                            : LiveGoCachedImage(
                                url: item.posterUrl,
                                fit: BoxFit.cover,
                                role: LiveGoImageRole.poster,
                                tv: tv,
                              ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xAA020617)],
                            ),
                          ),
                        ),
                        Positioned(top: 8, left: 8, child: _Badge(text: '${item.episodes} Ep')),
                        if (item.updated) const Positioned(top: 8, right: 8, child: _Badge(text: 'UPDATE')),
                        if (fav) const Positioned(right: 8, top: 38, child: _RoundIcon(icon: Icons.favorite_rounded)),
                        Positioned(right: 8, bottom: 12, child: _Badge(text: item.rating.toStringAsFixed(1))),
                        if (progress > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(AppTheme.cyan),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tv ? 14 : 13,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  const _RoundIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
      child: Icon(icon, color: AppTheme.cyan, size: 15),
    );
  }
}
