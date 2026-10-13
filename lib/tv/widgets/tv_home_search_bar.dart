import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

/// Search bar Home TV.
///
/// Styling mengikuti border chip provider/kategori (TvChipRow):
/// - pill (radius 999), tinggi 32
/// - border: fokus -> whiteGlow 1.6, default -> putih 0.075 0.8
/// - background: fokus -> gradasi cyan, default -> surface2 0.82
class TvHomeSearchBar extends StatelessWidget {
  final FocusNode focusNode;
  final bool? focusedOverride;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final FocusOnKeyEventCallback onKey;

  const TvHomeSearchBar({
    super.key,
    required this.focusNode,
    this.focusedOverride,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusedOverride ?? focusNode.hasFocus;
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
              borderRadius: BorderRadius.circular(999),
              focusColor: Colors.transparent,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  gradient: focused
                      ? LinearGradient(colors: [AppTheme.cyan.withOpacity(0.13), AppTheme.surface3.withOpacity(0.98)])
                      : null,
                  color: focused ? null : AppTheme.surface2.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: focused ? AppTheme.whiteGlow : Colors.white.withOpacity(0.075),
                    width: focused ? 1.6 : 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: focused ? Colors.white : AppTheme.textSoft,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'Cari film, serial...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const Text(
                      'OK buka Cari',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
