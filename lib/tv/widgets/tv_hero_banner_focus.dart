import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/hero_banner.dart';

class TvHeroBannerFocus extends StatelessWidget {
  final ContentItem? item;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback? onTap;
  final FocusOnKeyEventCallback onKey;

  const TvHeroBannerFocus({
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
              borderRadius: BorderRadius.circular(28),
              focusColor: Colors.transparent,
              child: Container(
                height: 202,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.surface2, AppTheme.bgDeep],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.92),
                    width: focused ? 2.4 : 1.0,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: focused ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.045)),
                  ),
                  child: item != null ? HeroBanner(item: item!, tv: true) : const _TvBannerSkeleton(height: 178),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TvBannerSkeleton extends StatelessWidget {
  final double height;
  const _TvBannerSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
    );
  }
}
