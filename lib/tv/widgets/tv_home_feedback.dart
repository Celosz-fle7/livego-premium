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
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.wifi_off_rounded : Icons.sync_rounded,
            size: 15,
            color: hasError ? Colors.orangeAccent.withOpacity(0.86) : TvFocusStyle.focusBlue.withOpacity(0.72),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
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
      height: 238,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: focused ? AppTheme.surface3.withOpacity(0.88) : AppTheme.surface2.withOpacity(0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: focused ? TvFocusStyle.focusBlue : AppTheme.border, width: focused ? 2 : 1),
        boxShadow: focused ? [TvFocusStyle.glow(0.08, 8)] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasError ? Icons.cloud_off_rounded : Icons.movie_filter_rounded,
            color: focused ? Colors.white70 : Colors.white30,
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            hasError ? 'Konten belum bisa dimuat' : 'Belum ada konten di kategori ini',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasError ? retryHint : 'OK refresh • LEFT ke menu • UP ke kategori',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class TvSkeletonBlock extends StatelessWidget {
  final double height;
  const TvSkeletonBlock({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
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
