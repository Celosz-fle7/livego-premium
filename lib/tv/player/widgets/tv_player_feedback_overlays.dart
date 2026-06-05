import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvPlayerLoadingOverlay extends StatelessWidget {
  final String title;
  final int episode;
  final String message;

  const TvPlayerLoadingOverlay({
    super.key,
    required this.title,
    required this.episode,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.cyan.withOpacity(0.32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(color: AppTheme.cyan, strokeWidth: 3),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Episode $episode',
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TvPlayerStatusToast extends StatelessWidget {
  final String message;

  const TvPlayerStatusToast({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class TvPlayerSubtitleOverlay extends StatelessWidget {
  final String text;

  const TvPlayerSubtitleOverlay({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.62),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.25,
              decoration: TextDecoration.none,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}
