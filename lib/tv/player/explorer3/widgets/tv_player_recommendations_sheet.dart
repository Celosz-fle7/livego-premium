import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../models/content_item.dart';
import '../../../../services/image/image_quality_config.dart';
import '../../../../shared/widgets/livego_cached_image.dart';

/// YouTube TV-Style Horizontal Recommendations Rail for TV Player.
class TvPlayerRecommendationsSheet extends StatelessWidget {
  final List<ContentItem> items;
  final int cursor;
  final String currentTitle;

  const TvPlayerRecommendationsSheet({
    super.key,
    required this.items,
    required this.cursor,
    required this.currentTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeCursor = cursor.clamp(0, items.length - 1).toInt();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.96),
            Colors.black.withOpacity(0.82),
            Colors.transparent,
          ],
          stops: const [0.0, 0.75, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.activeGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'REKOMENDASI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Konten Terkait • OK untuk putar • UP untuk kontrol • BACK untuk tutup',
                style: TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                final focused = index == safeCursor;
                return _RecommendationCard(
                  item: item,
                  focused: focused,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final ContentItem item;
  final bool focused;

  const _RecommendationCard({
    required this.item,
    required this.focused,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      width: focused ? 122 : 112,
      transform: Matrix4.identity()..scale(focused ? 1.04 : 1.0),
      transformAlignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? AppTheme.cyan : Colors.white.withOpacity(0.08),
          width: focused ? 2.4 : 1.0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppTheme.cyan.withOpacity(0.4),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LiveGoCachedImage(
              url: item.posterUrl,
              fit: BoxFit.cover,
              role: LiveGoImageRole.poster,
              tv: true,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: focused ? Colors.white : Colors.white70,
                    fontSize: 10.5,
                    fontWeight: focused ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
