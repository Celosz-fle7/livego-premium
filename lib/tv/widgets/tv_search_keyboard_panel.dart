import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class TvSearchKeyboardPanel extends StatelessWidget {
  const TvSearchKeyboardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.74),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: [
            const Icon(Icons.keyboard_rounded, color: AppTheme.cyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keyboard TV: ketik kata kunci lalu tekan Enter/Search. D-Pad bawah masuk hasil, BACK dari hasil kembali ke input.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textSoft.withOpacity(0.86), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
