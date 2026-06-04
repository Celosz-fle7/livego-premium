import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class TvSkeletonBlock extends StatelessWidget {
  final double height;
  final double radius;
  const TvSkeletonBlock({super.key, required this.height, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surface.withOpacity(0.82),
              AppTheme.surface2.withOpacity(0.72),
              AppTheme.surface.withOpacity(0.58),
            ],
          ),
          border: Border.all(color: AppTheme.border.withOpacity(0.7)),
        ),
      ),
    );
  }
}

class TvProfessionalGridSkeleton extends StatelessWidget {
  final int columns;
  final int rows;
  const TvProfessionalGridSkeleton({super.key, this.columns = 6, this.rows = 2});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            Row(
              children: [
                for (var c = 0; c < columns; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: c == columns - 1 ? 0 : 12),
                      child: const TvSkeletonPoster(),
                    ),
                  ),
              ],
            ),
            if (r != rows - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class TvSkeletonPoster extends StatelessWidget {
  const TvSkeletonPoster({super.key});

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 2 / 3,
      child: TvSkeletonBlock(height: double.infinity, radius: 18),
    );
  }
}

class TvDetailSkeleton extends StatelessWidget {
  const TvDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(46, 32, 46, 46),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvSkeletonBlock(height: 48, radius: 16),
            SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 210, child: TvSkeletonPoster()),
                SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TvSkeletonBlock(height: 54, radius: 18),
                      SizedBox(height: 14),
                      TvSkeletonBlock(height: 34, radius: 999),
                      SizedBox(height: 18),
                      TvSkeletonBlock(height: 116, radius: 20),
                      SizedBox(height: 24),
                      TvSkeletonBlock(height: 54, radius: 18),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TvFriendlyErrorPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const TvFriendlyErrorPanel({super.key, this.icon = Icons.wifi_off_rounded, required this.title, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: AppTheme.activeGradient, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 6),
                Text(message, style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
        ],
      ),
    );
  }
}
