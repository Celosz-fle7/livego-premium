import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../theme/tv_focus_style.dart';

/// Lightweight reusable TV poster tile.
///
/// Keep this widget small and isolated so focus repaint does not force a whole
/// TV screen rebuild. All poster grids should migrate to this widget before
/// public release.
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
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          return Focus(
            focusNode: focusNode,
            skipTraversal: true,
            autofocus: false,
            onKeyEvent: onKey,
            onFocusChange: (v) {
              if (v) onFocus();
            },
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              focusColor: Colors.transparent,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        // TV remote sync rule:
                        // Focus paint must be cheap and layout-stable. Do not
                        // change border width or add glow per move; low-end STB
                        // can paint that one frame late and make the cursor feel
                        // behind the remote.
                        border: Border.all(
                          color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.42),
                          width: 1.4,
                        ),
                        boxShadow: null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            item.posterUrl.isEmpty
                                ? Container(
                                    color: AppTheme.surface2,
                                    child: const Icon(
                                      Icons.movie_rounded,
                                      color: Colors.white38,
                                      size: 44,
                                    ),
                                  )
                                : LiveGoCachedImage(
                                    url: item.posterUrl,
                                    fit: BoxFit.cover,
                                    // Do not switch image role on focus. Changing
                                    // thumbnail -> poster while moving the remote
                                    // can reload/repaint the image and make the
                                    // screen look one step behind the cursor.
                                    role: LiveGoImageRole.thumbnail,
                                    tv: true,
                                  ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Color(0xCC010409)],
                                ),
                              ),
                            ),
                            Positioned(top: 8, left: 8, child: _TvPosterBadge(text: '${item.episodes} Ep')),
                            if (item.updated) const Positioned(top: 8, right: 8, child: _TvPosterBadge(text: 'UPDATE')),
                            Positioned(right: 8, bottom: 12, child: _TvPosterBadge(text: item.rating.toStringAsFixed(1))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.4,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TvPosterBadge extends StatelessWidget {
  final String text;
  const _TvPosterBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TvFocusStyle.focusBlue.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.4,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
