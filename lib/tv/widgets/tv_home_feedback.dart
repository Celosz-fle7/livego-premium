import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../theme/tv_focus_style.dart';

class TvHomeStatusLine extends StatelessWidget {
  final bool refreshing;
  final bool hasError;
  final bool fromCache;

  const TvHomeStatusLine({
    super.key,
    required this.refreshing,
    required this.hasError,
    required this.fromCache,
  });

  @override
  Widget build(BuildContext context) {
    final text = hasError
        ? (fromCache
            ? 'Konten cache ditampilkan. Source sedang lambat, remote tetap bisa dipakai.'
            : 'Sebagian data gagal dimuat. Coba ganti platform atau refresh nanti.')
        : (refreshing
            ? 'Konten tampil dulu, pembaruan berjalan di belakang.'
            : 'Konten dari cache.');

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: (hasError ? Colors.orangeAccent : TvFocusStyle.focusBlue).withOpacity(0.075),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (hasError ? Colors.orangeAccent : TvFocusStyle.focusBlue).withOpacity(0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasError ? Icons.wifi_off_rounded : Icons.sync_rounded,
              size: 14,
              color: hasError ? Colors.orangeAccent.withOpacity(0.90) : TvFocusStyle.focusBlue.withOpacity(0.78),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.6,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TvHomeEmptyState extends StatelessWidget {
  final bool hasError;
  final bool focused;
  final String retryHint;

  const TvHomeEmptyState({
    super.key,
    required this.hasError,
    this.focused = false,
    this.retryHint = 'OK coba lagi • LEFT ke menu • UP ke kategori',
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: 198,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? AppTheme.surface3.withOpacity(0.82) : AppTheme.surface2.withOpacity(0.58),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: focused ? TvFocusStyle.focusBlue : AppTheme.border, width: focused ? 2.2 : 1),
          boxShadow: focused ? [TvFocusStyle.glow(0.08, 8)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.cloud_off_rounded : Icons.movie_filter_rounded,
              color: focused ? Colors.white70 : Colors.white30,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              hasError ? 'Konten belum bisa dimuat / offline' : 'Belum ada konten di kategori ini',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14.2,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasError ? retryHint : 'OK refresh • LEFT ke menu • UP ke kategori',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TvContentGridHeader extends StatelessWidget {
  final String title;

  const TvContentGridHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: TvFocusStyle.focusBlue.withOpacity(0.70),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
                fontSize: 13.4,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
