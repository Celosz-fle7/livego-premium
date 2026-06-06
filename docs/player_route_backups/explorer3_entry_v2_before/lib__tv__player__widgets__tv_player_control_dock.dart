import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/app_theme.dart';

class TvPlayerControlDock extends StatelessWidget {
  final VideoPlayerController controller;
  final bool playing;
  final double speed;
  final String quality;
  final String audioTrack;
  final String subtitleStatus;
  final int focusedIndex;
  final bool progressFocused;
  final bool fitCover;
  final bool favorite;

  const TvPlayerControlDock({
    super.key,
    required this.controller,
    required this.playing,
    required this.speed,
    required this.quality,
    required this.audioTrack,
    required this.subtitleStatus,
    required this.focusedIndex,
    required this.progressFocused,
    required this.fitCover,
    required this.favorite,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.90),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.34)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_fmt(value.position), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(width: 18),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(progressFocused ? 4 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: progressFocused ? AppTheme.cyan : Colors.transparent, width: 2),
                    ),
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
                ),
                const SizedBox(width: 18),
                Text(_fmt(value.duration), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DockButton(icon: Icons.skip_previous_rounded, label: 'PREV', focused: focusedIndex == 0),
                _DockButton(icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded, label: 'PLAY', active: true, focused: focusedIndex == 1),
                _DockButton(icon: Icons.skip_next_rounded, label: 'NEXT', focused: focusedIndex == 2),
                _DockButton(icon: Icons.video_library_rounded, label: 'EPISODE', focused: focusedIndex == 3),
                _DockTextButton(text: quality.toUpperCase(), focused: focusedIndex == 4),
                _DockButton(icon: Icons.subtitles_rounded, label: 'SUB', focused: focusedIndex == 5),
                _DockButton(icon: Icons.audiotrack_rounded, label: 'AUDIO', focused: focusedIndex == 6),
                _DockButton(icon: Icons.tune_rounded, label: 'MORE', focused: focusedIndex == 7),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool focused;

  const _DockButton({required this.icon, required this.label, this.active = false, this.focused = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: focused ? AppTheme.cyan.withOpacity(0.20) : (active ? AppTheme.cyan.withOpacity(0.13) : Colors.white.withOpacity(0.055)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focused ? AppTheme.cyan : (active ? AppTheme.cyan.withOpacity(0.75) : Colors.white12), width: focused ? 2.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: focused || active ? Colors.white : Colors.white70, size: 23),
          const SizedBox(height: 1),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: focused ? Colors.white : AppTheme.textSoft, fontSize: 8.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _DockTextButton extends StatelessWidget {
  final String text;
  final bool focused;
  const _DockTextButton({required this.text, this.focused = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      constraints: const BoxConstraints(minWidth: 74),
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: focused ? AppTheme.cyan.withOpacity(0.20) : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focused ? AppTheme.cyan : Colors.white12, width: focused ? 2.5 : 1),
      ),
      child: Text(text, style: TextStyle(color: focused ? Colors.white : Colors.white, fontSize: 14, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
    );
  }
}
