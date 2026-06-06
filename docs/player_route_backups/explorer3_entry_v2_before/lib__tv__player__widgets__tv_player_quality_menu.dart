import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvPlayerQualityMenu extends StatelessWidget {
  final List<String> qualities;
  final int focusedIndex;

  const TvPlayerQualityMenu({
    super.key,
    required this.qualities,
    required this.focusedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return _MenuColumn(
      title: 'Kualitas',
      items: qualities,
      focusedIndex: focusedIndex,
    );
  }
}

class _MenuColumn extends StatelessWidget {
  final String title;
  final List<String> items;
  final int focusedIndex;

  const _MenuColumn({
    required this.title,
    required this.items,
    required this.focusedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: i == focusedIndex ? AppTheme.cyan.withOpacity(0.16) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i == focusedIndex ? AppTheme.cyan : Colors.white12),
              ),
              child: Text(items[i], style: TextStyle(color: i == focusedIndex ? AppTheme.cyan : Colors.white70, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            ),
        ],
      ),
    );
  }
}
