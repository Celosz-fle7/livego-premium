import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvPlayerChoicePanel extends StatelessWidget {
  final String title;
  final String hint;
  final List<String> choices;
  final int cursor;
  final int activeIndex;

  const TvPlayerChoicePanel({
    super.key,
    required this.title,
    required this.hint,
    required this.choices,
    required this.cursor,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final rows = choices.isEmpty ? const <String>['Tidak tersedia'] : choices;
    final safeCursor = cursor.clamp(0, rows.length - 1).toInt();
    var start = safeCursor - 3;
    if (start < 0) start = 0;
    var end = start + 6;
    if (end >= rows.length) {
      end = rows.length - 1;
      start = (end - 6).clamp(0, rows.length - 1).toInt();
    }
    final visible = rows.sublist(start, end + 1);

    return RepaintBoundary(
      child: Container(
        width: 370,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.38)),
          boxShadow: [
            BoxShadow(color: AppTheme.cyan.withOpacity(0.05), blurRadius: 10),
            const BoxShadow(color: Colors.black87, blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.cyan.withOpacity(0.22)),
                  ),
                  child: Text(
                    '${safeCursor + 1}/${rows.length}',
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: const TextStyle(
                color: AppTheme.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < visible.length; i++) ...[
              _TvPlayerChoiceRow(
                text: visible[i],
                focused: start + i == safeCursor,
                active: start + i == activeIndex,
              ),
              if (i != visible.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _TvPlayerChoiceRow extends StatelessWidget {
  final String text;
  final bool focused;
  final bool active;

  const _TvPlayerChoiceRow({
    required this.text,
    required this.focused,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: focused
            ? AppTheme.cyan.withOpacity(0.18)
            : (active ? Colors.white.withOpacity(0.075) : Colors.white.withOpacity(0.045)),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: focused
              ? AppTheme.cyan
              : (active ? AppTheme.cyan.withOpacity(0.40) : Colors.white12),
          width: focused ? 2 : 1,
        ),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.10), blurRadius: 8)] : null,
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: active || focused ? AppTheme.cyan : Colors.white38,
            size: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: focused ? Colors.white : (active ? AppTheme.cyan : Colors.white70),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
