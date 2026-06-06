import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/app_theme.dart';

class TvPlayerExplorer3Controls extends StatelessWidget {
  final VideoPlayerController controller;
  final String title;
  final int episode;
  final String status;

  const TvPlayerExplorer3Controls({
    super.key,
    required this.controller,
    required this.title,
    required this.episode,
    required this.status,
  });

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'EP $episode',
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  _fmt(value.position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: false,
                    colors: const VideoProgressColors(
                      playedColor: AppTheme.cyan,
                      bufferedColor: AppTheme.whiteGlow,
                      backgroundColor: AppTheme.borderSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  _fmt(value.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              status.trim().isEmpty
                  ? 'OK Play/Pause   ←/→ Seek 10s   UP/DOWN Controls   BACK Hide/Exit'
                  : '$status  •  OK Play/Pause   ←/→ Seek 10s   BACK Hide/Exit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
