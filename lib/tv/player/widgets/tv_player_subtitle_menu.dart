import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvPlayerSubtitleMenu extends StatelessWidget {
  final List<String> subtitles;
  final int focusedIndex;

  const TvPlayerSubtitleMenu({
    super.key,
    required this.subtitles,
    required this.focusedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Subtitle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          for (var i = 0; i < subtitles.length; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: i == focusedIndex ? AppTheme.cyan.withOpacity(0.16) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i == focusedIndex ? AppTheme.cyan : Colors.white12),
              ),
              child: Text(subtitles[i], style: TextStyle(color: i == focusedIndex ? AppTheme.cyan : Colors.white70, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            ),
        ],
      ),
    );
  }
}
