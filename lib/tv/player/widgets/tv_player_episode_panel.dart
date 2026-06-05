import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/livego_episode.dart';

class TvPlayerEpisodePanel extends StatelessWidget {
  final List<LiveGoEpisode> episodes;
  final int total;
  final int selected;
  final int cursor;
  final Set<int> broken;

  const TvPlayerEpisodePanel({
    super.key,
    required this.episodes,
    required this.total,
    required this.selected,
    required this.cursor,
    this.broken = const <int>{},
  });

  @override
  Widget build(BuildContext context) {
    final totalSafe = total.clamp(1, 120).toInt();
    final visible = _visibleEpisodeRows(
      episodes: episodes,
      totalSafe: totalSafe,
      selected: selected,
      cursor: cursor,
    );

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daftar Episode', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.white.withOpacity(0.06), border: Border.all(color: Colors.white12)),
              child: Text('$totalSafe Ep • UP/DOWN pilih • OK putar • BACK tutup', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            ),
            const SizedBox(height: 8),
            Text('Aktif: Episode $selected • Cursor: Episode $cursor', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final row = visible[index];
                  final ep = row.index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EpisodeListRow(
                      ep: ep,
                      title: row.title,
                      selected: ep == selected,
                      focused: ep == cursor,
                      broken: broken.contains(ep),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


List<_EpisodePanelRowData> _visibleEpisodeRows({
  required List<LiveGoEpisode> episodes,
  required int totalSafe,
  required int selected,
  required int cursor,
}) {
  const windowSize = 11;
  final safeTotal = totalSafe.clamp(1, 120).toInt();

  if (episodes.isEmpty) {
    final center = cursor > 0 ? cursor : selected;
    final safeCenter = center.clamp(1, safeTotal).toInt();
    final start = (safeCenter - 5).clamp(1, safeTotal).toInt();
    final end = (start + windowSize - 1).clamp(1, safeTotal).toInt();
    final correctedStart = (end - windowSize + 1).clamp(1, end).toInt();

    return List<_EpisodePanelRowData>.generate(
      end - correctedStart + 1,
      (index) {
        final ep = correctedStart + index;
        return _EpisodePanelRowData(index: ep, title: 'Episode $ep');
      },
      growable: false,
    );
  }

  final activePos = episodes.indexWhere((e) => e.index == cursor);
  final selectedPos = episodes.indexWhere((e) => e.index == selected);
  final center = activePos >= 0 ? activePos : (selectedPos >= 0 ? selectedPos : 0);
  final startPos = (center - 5).clamp(0, episodes.length - 1).toInt();
  final endPos = (startPos + windowSize - 1).clamp(0, episodes.length - 1).toInt();
  final correctedStart = (endPos - windowSize + 1).clamp(0, endPos).toInt();

  return List<_EpisodePanelRowData>.generate(
    endPos - correctedStart + 1,
    (index) {
      final row = episodes[correctedStart + index];
      final ep = row.index <= 0 ? correctedStart + index + 1 : row.index;
      final title = row.title.trim().isEmpty ? 'Episode $ep' : row.title.trim();
      return _EpisodePanelRowData(index: ep, title: title);
    },
    growable: false,
  );
}

class _EpisodePanelRowData {
  final int index;
  final String title;

  const _EpisodePanelRowData({
    required this.index,
    required this.title,
  });
}

class _EpisodeListRow extends StatelessWidget {
  final int ep;
  final String title;
  final bool selected;
  final bool focused;
  final bool broken;

  const _EpisodeListRow({required this.ep, required this.title, required this.selected, required this.focused, this.broken = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: focused ? AppTheme.cyan : (selected ? AppTheme.cyan.withOpacity(0.55) : Colors.white12), width: focused ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(
            broken ? Icons.error_outline_rounded : (selected ? Icons.play_arrow_rounded : Icons.radio_button_unchecked_rounded),
            color: broken ? Colors.orangeAccent : (selected || focused ? Colors.white : AppTheme.textSoft),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title.trim().isEmpty ? 'Episode $ep' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: focused || selected ? Colors.white : AppTheme.textSoft, fontSize: 15, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
          if (broken) const Text('GAGAL', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.none))
          else if (selected) const Text('DIPUTAR', style: TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}
