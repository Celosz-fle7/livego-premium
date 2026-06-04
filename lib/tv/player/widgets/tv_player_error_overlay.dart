import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvPlayerErrorOverlay extends StatelessWidget {
  final String title;
  final String message;
  final int episode;

  const TvPlayerErrorOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.episode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.62),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.redAccent.withOpacity(0.42)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            const SizedBox(height: 8),
            Text('Episode $episode', style: const TextStyle(color: AppTheme.cyan, fontSize: 14, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSoft, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            const SizedBox(height: 14),
            const Text('OK ulang • RIGHT episode berikut • BACK keluar', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}
