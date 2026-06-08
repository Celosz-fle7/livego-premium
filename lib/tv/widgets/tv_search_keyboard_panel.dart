import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class TvSearchKeyboardPanel extends StatelessWidget {
  const TvSearchKeyboardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface2.withOpacity(0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSoft.withOpacity(0.70)),
        ),
        child: Row(
          children: [
            const Icon(Icons.keyboard_rounded, color: AppTheme.cyan, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'OK/RIGHT ketik • ENTER cari • DOWN hasil • BACK tutup keyboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textSoft.withOpacity(0.88), fontSize: 11.4, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
