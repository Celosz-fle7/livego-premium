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
    if (total == null || total <= 1 || total >= 999) return 'EP $episode';
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
                  ? '←/→ pilih kontrol • OK aktifkan • DOWN episode • UP/MENU opsi • BACK sembunyi/keluar'
                  : '$status  •  ←/→ pilih kontrol • OK aktifkan • DOWN episode • BACK sembunyi/keluar',
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

class TvPlayerExplorer3InfoOverlay extends StatelessWidget {
  final String title;
  final int episode;
  final int totalEpisodes;
  final double speed;
  final String quality;
  final String subtitle;
  final bool autoNext;
  final bool muted;

  const TvPlayerExplorer3InfoOverlay({
    super.key,
    required this.title,
    required this.episode,
    required this.totalEpisodes,
    required this.speed,
    required this.quality,
    required this.subtitle,
    required this.autoNext,
    required this.muted,
  });

  String _speedText() => '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x';

  @override
  Widget build(BuildContext context) {
    final total = totalEpisodes <= 1 || totalEpisodes >= 999 ? '' : ' / $totalEpisodes';
    return IgnorePointer(
      child: Positioned(
        left: 48,
        right: 48,
        top: 0,
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      const SizedBox(height: 4),
                      Text(
                        'EP $episode$total • $_speedText() • $quality • Sub: $subtitle • Next: ${autoNext ? 'Auto' : 'Manual'} • ${muted ? 'Mute' : 'Audio Source'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TvPlayerExplorer3EpisodePanel extends StatelessWidget {
  final int selected;
  final int cursor;
  final int total;

  const TvPlayerExplorer3EpisodePanel({
    super.key,
    required this.selected,
    required this.cursor,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = total.clamp(1, 999).toInt();
    final start = (cursor - 5).clamp(1, safeTotal).toInt();
    final end = (start + 10).clamp(1, safeTotal).toInt();
    final fixedStart = (end - 10).clamp(1, safeTotal).toInt();
    final rows = [for (var ep = fixedStart; ep <= end; ep++) ep];

    return _PanelShell(
      width: 390,
      title: 'Episode',
      subtitle: 'UP/DOWN pilih • OK buka • BACK kembali',
      child: Column(
        children: [
          for (final ep in rows)
            _ChoiceRow(
              label: 'Episode $ep',
              value: ep == selected ? 'Now' : '',
              focused: ep == cursor,
              selected: ep == selected,
            ),
        ],
      ),
    );
  }
}

class TvPlayerExplorer3ChoicePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> choices;
  final int cursor;

  const TvPlayerExplorer3ChoicePanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.choices,
    required this.cursor,
  });

  @override
  Widget build(BuildContext context) {
    final rows = choices.isEmpty ? const <String>['Tidak tersedia'] : choices;
    final safeCursor = cursor.clamp(0, rows.length - 1).toInt();

    return _PanelShell(
      width: 330,
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _ChoiceRow(
              label: rows[i],
              value: i == safeCursor ? 'OK' : '',
              focused: i == safeCursor,
              selected: false,
            ),
        ],
      ),
    );
  }
}

class TvPlayerExplorer3OptionsPanel extends StatelessWidget {
  final int cursor;
  final String speed;
  final bool autoNext;
  final bool fitCover;
  final bool muted;
  final String quality;
  final String subtitle;

  const TvPlayerExplorer3OptionsPanel({
    super.key,
    required this.cursor,
    required this.speed,
    required this.autoNext,
    required this.fitCover,
    required this.muted,
    required this.quality,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (label: 'Speed', value: speed),
      (label: 'Next Episode', value: autoNext ? 'Auto' : 'Manual'),
      (label: 'Layar', value: fitCover ? 'Cover' : 'Fit'),
      (label: 'Volume', value: muted ? 'Mute' : 'Normal'),
      (label: 'Quality', value: quality),
      (label: 'Subtitle', value: subtitle),
    ];
    final safeCursor = cursor.clamp(0, rows.length - 1).toInt();

    return _PanelShell(
      width: 330,
      title: 'Options',
      subtitle: 'UP/DOWN pilih • LEFT/RIGHT/OK ubah • BACK kembali',
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _ChoiceRow(
              label: rows[i].label,
              value: rows[i].value,
              focused: i == safeCursor,
              selected: false,
            ),
        ],
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  final double width;
  final String title;
  final String subtitle;
  final Widget child;

  const _PanelShell({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.38)),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 24),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool focused;
  final bool selected;

  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.focused,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: focused ? AppTheme.activeGradient : null,
        color: focused ? null : (selected ? AppTheme.surface3.withOpacity(0.92) : Colors.white.withOpacity(0.045)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppTheme.whiteGlow : (selected ? AppTheme.cyan.withOpacity(0.55) : Colors.white12),
          width: focused ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: focused ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: focused ? Colors.white : AppTheme.cyan,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
        ],
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
