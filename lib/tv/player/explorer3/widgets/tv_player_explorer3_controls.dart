import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/app_theme.dart';

class TvPlayerExplorer3Controls extends StatelessWidget {
  final VideoPlayerController controller;
  final String title;
  final int episode;
  final int? totalEpisodes;
  final String status;
  final int selectedIndex;
  final bool isPlaying;
  final double speed;

  const TvPlayerExplorer3Controls({
    super.key,
    required this.controller,
    required this.title,
    required this.episode,
    required this.status,
    required this.selectedIndex,
    required this.isPlaying,
    required this.speed,
    this.totalEpisodes,
  });

  static const List<_Explorer3ControlItem> _items = [
    _Explorer3ControlItem(Icons.skip_previous_rounded, 'Prev'),
    _Explorer3ControlItem(Icons.play_arrow_rounded, 'Play'),
    _Explorer3ControlItem(Icons.skip_next_rounded, 'Next'),
    _Explorer3ControlItem(Icons.format_list_numbered_rounded, 'Episode'),
    _Explorer3ControlItem(Icons.hd_rounded, 'Quality'),
    _Explorer3ControlItem(Icons.subtitles_rounded, 'Subtitle'),
    _Explorer3ControlItem(Icons.speed_rounded, 'Speed'),
    _Explorer3ControlItem(Icons.more_horiz_rounded, 'More'),
  ];

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _episodeLabel() {
    final total = totalEpisodes;
    if (total == null || total <= 1) return 'EP $episode';
    return 'EP $episode / $total';
  }

  String _speedLabel() {
    final raw = speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2);
    return '${raw}x';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final safeSelected = selectedIndex.clamp(0, _items.length - 1).toInt();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.34)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18),
        ],
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
                  _episodeLabel(),
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
            Row(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  Expanded(
                    child: _DockButton(
                      item: _items[i].copyWith(
                        label: i == 1
                            ? (isPlaying ? 'Pause' : 'Play')
                            : i == 6
                                ? 'Speed ${_speedLabel()}'
                                : _items[i].label,
                        icon: i == 1
                            ? (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)
                            : _items[i].icon,
                      ),
                      selected: i == safeSelected,
                    ),
                  ),
                  if (i < _items.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status.trim().isEmpty
                  ? '←/→ pilih kontrol • OK aktifkan • BACK sembunyi/keluar'
                  : '$status  •  ←/→ pilih kontrol • OK aktifkan • BACK sembunyi/keluar',
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

class _DockButton extends StatelessWidget {
  final _Explorer3ControlItem item;
  final bool selected;

  const _DockButton({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      height: 54,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: selected ? AppTheme.activeGradient : null,
        color: selected ? null : AppTheme.surface2.withOpacity(0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.whiteGlow : AppTheme.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: Colors.white, size: 20),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _Explorer3ControlItem {
  final IconData icon;
  final String label;

  const _Explorer3ControlItem(this.icon, this.label);

  _Explorer3ControlItem copyWith({
    IconData? icon,
    String? label,
  }) {
    return _Explorer3ControlItem(
      icon ?? this.icon,
      label ?? this.label,
    );
  }
}
