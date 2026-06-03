import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../services/download/download_service.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../models/tv_zone.dart';
import '../theme/tv_focus_style.dart';
import '../utils/tv_focus_utils.dart';
import 'tv_player_screen.dart';

class TvDownloadsScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final VoidCallback? onBackToNav;
  final VoidCallback? onBackToHome;
  final VoidCallback? onPlayerRouteOpen;
  final VoidCallback? onPlayerRouteClosed;
  final int focusTicket;

  const TvDownloadsScreen({
    super.key,
    this.onMoveToNav,
    this.onBackToNav,
    this.onBackToHome,
    this.onPlayerRouteOpen,
    this.onPlayerRouteClosed,
    this.focusTicket = 0,
  });

  @override
  State<TvDownloadsScreen> createState() => _TvDownloadsScreenState();
}

class _TvDownloadsScreenState extends State<TvDownloadsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _rowNodes = [];
  late final FocusNode _emptyNode;

  TvZone _zone = TvZone.list;
  int _lastRow = 0;
  bool _entryPending = false;
  bool _openingPlayer = false;

  @override
  void initState() {
    super.initState();
    _emptyNode = FocusNode(skipTraversal: true, debugLabel: 'tv-download-empty');
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusEntry());
  }

  @override
  void didUpdateWidget(covariant TvDownloadsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) _focusEntry();
  }

  @override
  void dispose() {
    for (final node in _rowNodes) {
      node.dispose();
    }
    _emptyNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncRowNodes(int count) {
    while (_rowNodes.length < count) {
      _rowNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-download-row-${_rowNodes.length}'));
    }
    while (_rowNodes.length > count) {
      _rowNodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_rowNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = _rowNodes.length - 1;
    return value > max ? max : value;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space;
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.browserBack;
  }

  void _moveToNav() {
    _zone = TvZone.nav;
    if (widget.onMoveToNav != null) {
      widget.onMoveToNav?.call();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  void _backToNav() {
    _zone = TvZone.nav;
    if (widget.onBackToNav != null) {
      widget.onBackToNav?.call();
    } else {
      _moveToNav();
    }
  }

  void _backToHome() {
    _zone = TvZone.banner;
    if (widget.onBackToHome != null) {
      widget.onBackToHome?.call();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  void _focusEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
  }

  void _tryFocusEntry() {
    if (!mounted || !_entryPending) return;
    final rows = DownloadService.items;
    if (rows.isEmpty) {
      _entryPending = false;
      tvFocusComfort(_emptyNode, topMargin: 110, bottomMargin: 180);
      return;
    }
    if (_rowNodes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
      return;
    }
    _entryPending = false;
    _focusRow(_lastRow);
  }

  void _focusRow(int index) {
    if (_rowNodes.isEmpty) return;
    _zone = TvZone.list;
    _lastRow = _safe(index);
    tvFocusComfort(_rowNodes[_lastRow], topMargin: 110, bottomMargin: 180);
  }

  void _open(DownloadRecord record) {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: record.item, onExitToHome: widget.onPlayerRouteClosed))).whenComplete(() {
      _openingPlayer = false;
      widget.onPlayerRouteClosed?.call();
      if (!mounted) return;
      void restore() {
        if (mounted) _focusRow(_lastRow);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => restore());
    });
  }

  KeyEventResult _emptyKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNav();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _backToNav();
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _rowKey(int index, DownloadRecord record, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _lastRow = index;
      _moveToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusRow(index == 0 ? 0 : index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusRow(index < _rowNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
      _lastRow = index;
      _open(record);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _lastRow = index;
      _backToNav();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final rows = DownloadService.items;
        _syncRowNodes(rows.length);
        if (_entryPending) WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());

        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.goBack): _DownloadsBackIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _DownloadsBackIntent(),
            SingleActivator(LogicalKeyboardKey.browserBack): _DownloadsBackIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _DownloadsBackIntent: CallbackAction<_DownloadsBackIntent>(onInvoke: (_) {
                _backToNav();
                return null;
              }),
            },
            child: SafeArea(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(32, 32, 44, 190),
              children: [
                _DownloadHeader(count: rows.length),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  Focus(
                    focusNode: _emptyNode,
                    skipTraversal: true,
                    autofocus: false,
                    onKeyEvent: _emptyKey,
                    child: _EmptyDownloads(node: _emptyNode),
                  )
                else ...[
                  Row(
                    children: [
                      const Text('Daftar Unduhan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      const Spacer(),
                      Text('Remote: OK buka • ← navbar • Back navbar', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < rows.length; i++)
                    _DownloadRow(node: _rowNodes[i], record: rows[i], onTap: () => _open(rows[i]), onKey: (node, event) => _rowKey(i, rows[i], event)),
                ],
                const SizedBox(height: 130),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

class _DownloadsBackIntent extends Intent {
  const _DownloadsBackIntent();
}

class _DownloadHeader extends StatelessWidget {
  final int count;
  const _DownloadHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.94), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(gradient: AppTheme.activeGradient, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.download_done_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Download', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 4),
                Text('$count episode tersimpan / antre', style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final FocusNode node;
  final DownloadRecord record;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _DownloadRow({required this.node, required this.record, required this.onKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        final status = _statusText(record.status);
        return Focus(
          focusNode: node,
          skipTraversal: true,
          autofocus: false,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(width: 58, height: 82, child: LiveGoCachedImage(url: record.item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                        const SizedBox(height: 4),
                        Text('${record.item.platformSlug} • Eps ${record.episode} • ${record.quality}', style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: record.progress <= 0 ? null : record.progress.clamp(0.0, 1.0).toDouble(), minHeight: 5, backgroundColor: Colors.white12, color: AppTheme.cyan),
                        const SizedBox(height: 6),
                        Text(record.error.isNotEmpty ? '$status • ${record.error}' : status, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11, decoration: TextDecoration.none)),
                      ],
                    ),
                  ),
                  Icon(Icons.play_arrow_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _statusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return 'Menunggu';
      case DownloadStatus.downloading:
        return 'Mengunduh';
      case DownloadStatus.completed:
        return 'Selesai';
      case DownloadStatus.failed:
        return 'Gagal';
      case DownloadStatus.canceled:
        return 'Dibatalkan';
    }
  }
}

class _EmptyDownloads extends StatelessWidget {
  final FocusNode node;
  const _EmptyDownloads({required this.node});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return AnimatedContainer(
          duration: TvFocusStyle.fast,
          height: 260,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.92), borderRadius: BorderRadius.circular(24), border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_rounded, color: AppTheme.cyan, size: 52),
              SizedBox(height: 14),
              Text('Download masih kosong', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              SizedBox(height: 8),
              Text('Episode yang diunduh dari player akan muncul di sini.', style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            ],
          ),
        );
      },
    );
  }
}
