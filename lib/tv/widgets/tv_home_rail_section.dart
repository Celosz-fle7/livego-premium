import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../focus/tv_focus_utils.dart';
import '../providers/tv_home_rows_provider.dart';
import '../theme/tv_focus_style.dart';

class TvHomeProfessionalRows extends StatefulWidget {
  final ValueChanged<ContentItem> onOpen;
  final VoidCallback onMoveToNav;
  final VoidCallback onBackToCategory;
  final VoidCallback onMoveToGrid;

  const TvHomeProfessionalRows({
    super.key,
    required this.onOpen,
    required this.onMoveToNav,
    required this.onBackToCategory,
    required this.onMoveToGrid,
  });

  @override
  State<TvHomeProfessionalRows> createState() => TvHomeProfessionalRowsState();
}

class TvHomeProfessionalRowsState extends State<TvHomeProfessionalRows> {
  final List<FocusNode> _continueNodes = <FocusNode>[];
  final List<FocusNode> _myListNodes = <FocusNode>[];
  int _continueIndex = 0;
  int _myListIndex = 0;

  @override
  void dispose() {
    _disposeNodes(_continueNodes);
    _disposeNodes(_myListNodes);
    super.dispose();
  }

  void _disposeNodes(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.dispose();
    }
    nodes.clear();
  }

  void _syncNodes(List<FocusNode> nodes, int count, String label) {
    while (nodes.length < count) {
      nodes.add(FocusNode(skipTraversal: true, debugLabel: '$label-${nodes.length}'));
    }
    while (nodes.length > count) {
      nodes.removeLast().dispose();
    }
  }

  bool get hasRows => _continueNodes.isNotEmpty || _myListNodes.isNotEmpty;

  bool focusFirst() {
    if (_continueNodes.isNotEmpty) return _focusContinue(_continueIndex, throttle: false);
    if (_myListNodes.isNotEmpty) return _focusMyList(_myListIndex, throttle: false);
    return false;
  }

  bool focusMyList() {
    if (_myListNodes.isNotEmpty) return _focusMyList(_myListIndex, throttle: false);
    if (_continueNodes.isNotEmpty) return _focusContinue(_continueIndex, throttle: false);
    return false;
  }

  bool _focusContinue(int index, {bool throttle = true}) {
    if (_continueNodes.isEmpty) return false;
    final target = index.clamp(0, _continueNodes.length - 1).toInt();
    final ok = tvFocusComfort(_continueNodes[target], topMargin: 96, bottomMargin: 190, throttle: throttle);
    if (ok) _continueIndex = target;
    return ok;
  }

  bool _focusMyList(int index, {bool throttle = true}) {
    if (_myListNodes.isEmpty) return false;
    final target = index.clamp(0, _myListNodes.length - 1).toInt();
    final ok = tvFocusComfort(_myListNodes[target], topMargin: 96, bottomMargin: 190, throttle: throttle);
    if (ok) _myListIndex = target;
    return ok;
  }

  KeyEventResult _continueKey(int index, WatchProgress progress, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key) || key == LogicalKeyboardKey.arrowUp) {
      widget.onBackToCategory();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        widget.onMoveToNav();
      } else {
        _focusContinue(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _continueNodes.length - 1) _focusContinue(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!_focusMyList(_myListIndex)) widget.onMoveToGrid();
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      widget.onOpen(progress.item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _myListKey(int index, ContentItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      if (!_focusContinue(_continueIndex, throttle: false)) widget.onBackToCategory();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!_focusContinue(_continueIndex)) widget.onBackToCategory();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        widget.onMoveToNav();
      } else {
        _focusMyList(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _myListNodes.length - 1) _focusMyList(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onMoveToGrid();
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      widget.onOpen(item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final rows = TvHomeRowsState.fromStore();
        _syncNodes(_continueNodes, rows.continueWatching.length, 'tv-home-continue');
        _syncNodes(_myListNodes, rows.myList.length, 'tv-home-mylist');
        if (!rows.hasAny) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rows.continueWatching.isNotEmpty) ...[
              _RailHeader(
                title: 'Lanjut Menonton',
                subtitle: '${rows.continueWatching.length} tontonan terakhir',
                icon: Icons.play_circle_fill_rounded,
              ),
              SizedBox(
                height: 154,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rows.continueWatching.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _ContinueCard(
                    node: _continueNodes[i],
                    progress: rows.continueWatching[i],
                    onKey: (node, event) => _continueKey(i, rows.continueWatching[i], event),
                    onTap: () => widget.onOpen(rows.continueWatching[i].item),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (rows.myList.isNotEmpty) ...[
              _RailHeader(
                title: 'My List',
                subtitle: '${rows.myList.length} judul favorit',
                icon: Icons.favorite_rounded,
              ),
              SizedBox(
                height: 154,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rows.myList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _PosterRailCard(
                    node: _myListNodes[i],
                    item: rows.myList[i],
                    onKey: (node, event) => _myListKey(i, rows.myList[i], event),
                    onTap: () => widget.onOpen(rows.myList[i]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class _RailHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _RailHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.cyan, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(width: 10),
          Text(subtitle, style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final FocusNode node;
  final WatchProgress progress;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _ContinueCard({required this.node, required this.progress, required this.onKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _RailCardShell(
      node: node,
      onKey: onKey,
      onTap: onTap,
      width: 310,
      childBuilder: (focused) => Row(
        children: [
          _RailPoster(url: progress.item.posterUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(progress.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 7),
                Text('Episode ${progress.episode} • ${(progress.ratio * 100).clamp(0, 99).toInt()}%', style: const TextStyle(color: AppTheme.cyan, fontSize: 11.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress.ratio <= 0 ? null : progress.ratio,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    color: AppTheme.cyan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterRailCard extends StatelessWidget {
  final FocusNode node;
  final ContentItem item;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _PosterRailCard({required this.node, required this.item, required this.onKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _RailCardShell(
      node: node,
      onKey: onKey,
      onTap: onTap,
      width: 250,
      childBuilder: (focused) => Row(
        children: [
          _RailPoster(url: item.posterUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 7),
                Text(item.platformSlug, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.cyan, fontSize: 11.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 5),
                Text(item.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSoft.withOpacity(0.76), fontSize: 11, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailCardShell extends StatelessWidget {
  final FocusNode node;
  final double width;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;
  final Widget Function(bool focused) childBuilder;

  const _RailCardShell({required this.node, required this.width, required this.onKey, required this.onTap, required this.childBuilder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              width: width,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1),
                boxShadow: focused ? [TvFocusStyle.glow(0.08, 8)] : null,
              ),
              child: childBuilder(focused),
            ),
          ),
        );
      },
    );
  }
}

class _RailPoster extends StatelessWidget {
  final String url;
  const _RailPoster({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        height: 116,
        child: LiveGoCachedImage(url: url, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
      ),
    );
  }
}
