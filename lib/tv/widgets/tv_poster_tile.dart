import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/livego_cached_image.dart';

/// Lightweight reusable TV poster tile.
///
/// TV performance rule:
/// - non-focused tile = poster + title only
/// - focused tile = clear border + small metadata badges
/// - no ripple, glow, shadow, gradient, scale, or extra repaint boundary here
///   because SliverGrid already owns child repaint boundaries.
class TvPosterTile extends StatelessWidget {
  final ContentItem item;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

  const TvPosterTile({
    super.key,
    required this.item,
    required this.focusNode,
    required this.onFocus,
    required this.onTap,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return Focus(
          focusNode: focusNode,
          skipTraversal: true,
          autofocus: false,
          onKeyEvent: onKey,
          onFocusChange: (value) {
            if (value) onFocus();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.34),
                        width: focused ? 2.4 : 0.6,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item.posterUrl.isEmpty
                              ? Container(
                                  color: AppTheme.surface2,
                                  child: const Icon(
                                    Icons.movie_rounded,
                                    color: Colors.white38,
                                    size: 42,
                                  ),
                                )
                              : LiveGoCachedImage(
                                  url: item.posterUrl,
                                  fit: BoxFit.cover,
                                  role: focused ? LiveGoImageRole.poster : LiveGoImageRole.thumbnail,
                                  tv: true,
                                ),
                          if (focused) ...[
                            Positioned(top: 7, left: 7, child: _TvPosterBadge(text: '${item.episodes} Ep')),
                            if (item.updated) const Positioned(top: 7, right: 7, child: _TvPosterBadge(text: 'UPDATE')),
                            Positioned(right: 7, bottom: 10, child: _TvPosterBadge(text: item.rating.toStringAsFixed(1))),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w900,
                    height: 1.06,
                    decoration: TextDecoration.none,
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

class _TvPosterBadge extends StatelessWidget {
  final String text;
  const _TvPosterBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.whiteGlow.withOpacity(0.28)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.2,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
