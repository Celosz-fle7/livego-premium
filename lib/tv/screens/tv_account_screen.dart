import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../focus/tv_focus_utils.dart';
import '../focus/tv_reachability.dart';
import '../theme/tv_focus_style.dart';
import 'tv_settings_screen.dart';
import 'tv_source_manager_screen.dart';

class TvAccountScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final VoidCallback? onBackToNav;
  final VoidCallback? onBackToHome;
  final ValueChanged<int>? onOpenNavIndex;
  final int focusTicket;

  const TvAccountScreen({
    super.key,
    this.onMoveToNav,
    this.onBackToNav,
    this.onBackToHome,
    this.onOpenNavIndex,
    this.focusTicket = 0,
  });

  @override
  State<TvAccountScreen> createState() => _TvAccountScreenState();
}

class _TvAccountScreenState extends State<TvAccountScreen> {
  final ScrollController _scroll = ScrollController();
  final List<FocusNode> _nodes = <FocusNode>[];
  int _index = 0;
  int _lastBackMs = 0;
  int _lastSelectMs = 0;
  int _focusRetryToken = 0;
  bool _openingSubscreen = false;

  List<_AccountItem> get _items => <_AccountItem>[
        _AccountItem(Icons.layers_rounded, 'Kelola Sumber Data', 'Atur Anichin, bahasa, kategori, dan platform aktif.', 'SOURCE', () => _push(const TvSourceManagerScreen())),
        _AccountItem(Icons.history_rounded, 'Riwayat Tontonan', 'Buka histori tontonan dari navbar TV.', '${LiveGoLocalStore.history.length}', () => widget.onOpenNavIndex?.call(2)),
        _AccountItem(Icons.favorite_rounded, 'Favorit', 'Daftar konten yang kamu simpan.', '${LiveGoLocalStore.favorites.length}', () => widget.onOpenNavIndex?.call(3)),
        _AccountItem(Icons.download_rounded, 'Download', 'Kelola unduhan dan episode offline.', '${LiveGoLocalStore.downloads.length}', () => widget.onOpenNavIndex?.call(1)),
        _AccountItem(Icons.tune_rounded, 'Pengaturan Tampilan', 'Mode tampilan, grid, ukuran poster, dan preferensi layar.', 'DISPLAY', () => _push(const TvSettingsScreen())),
        _AccountItem(Icons.info_outline_rounded, 'Tentang Aplikasi', 'Informasi LiveGo Premium, mode TV, dan status data.', 'INFO', () => _message('LiveGo Premium TV • data sinkron dengan mode HP')),
        _AccountItem(Icons.system_update_alt_rounded, 'Periksa Update', 'Cek versi terbaru dari build GitHub.', 'UPDATE', () => _message('Update mengikuti build GitHub Actions terbaru.')),
      ];

  @override
  void initState() {
    super.initState();
    _scheduleFocusRow(_index);
  }

  @override
  void didUpdateWidget(covariant TvAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _scheduleFocusRow(_index);
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _syncNodes(int count) {
    while (_nodes.length < count) {
      _nodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-account-row-${_nodes.length}'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_nodes.isEmpty) return 0;
    return value.clamp(0, _nodes.length - 1).toInt();
  }

  bool _focusRow(int index, {bool throttle = true}) {
    if (_nodes.isEmpty) return false;
    final target = _safe(index);
    final ok = tvFocusComfort(_nodes[target], topMargin: 104, bottomMargin: 180, throttle: throttle);
    if (ok) _index = target;
    return ok;
  }

  void _backToNav() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackMs < 420) return;
    _lastBackMs = now;

    // Leaving Account means Shell/Navbar owns the next focus. Cancel any
    // pending internal row restore so Account does not pull focus back.
    _focusRetryToken++;
    widget.onBackToNav?.call();
  }

  bool _selectAllowed([int ms = 300]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSelectMs < ms) return false;
    _lastSelectMs = now;
    return true;
  }

  void _scheduleFocusRow(int index, {int attempt = 0}) {
    if (!mounted) return;
    final token = ++_focusRetryToken;

    // Account owns only its internal menu focus. App-level bootstrap belongs to
    // TvShell, so avoid a second delayed retry ladder here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _focusRetryToken) return;
      _focusRow(index, throttle: false);
    });
  }

  void _push(Widget screen) {
    if (_openingSubscreen || !mounted) return;
    _openingSubscreen = true;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).whenComplete(() {
      _openingSubscreen = false;
      if (!mounted) return;
      _lastBackMs = DateTime.now().millisecondsSinceEpoch;
      _scheduleFocusRow(_index);
    });
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: AppTheme.surface2, duration: const Duration(seconds: 2)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusRow(_index, throttle: false);
    });
  }

  void _activateItem(int index, _AccountItem item) {
    if (!_selectAllowed()) return;
    _index = _safe(index);
    item.onTap();
  }

  KeyEventResult _rowKey(int index, _AccountItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = _safe(index);
    _index = current;
    if (tvIsBackKey(key)) {
      _backToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (current > 0) _focusRow(current - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (current < _nodes.length - 1) _focusRow(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _backToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || tvIsSelectKey(key)) {
      _activateItem(current, item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    _syncNodes(items.length);
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.goBack): _AccountBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _AccountBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _AccountBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AccountBackIntent: CallbackAction<_AccountBackIntent>(onInvoke: (_) {
            _backToNav();
            return null;
          }),
        },
        child: SafeArea(
          top: true,
          bottom: true,
          child: ValueListenableBuilder<int>(
            valueListenable: LiveGoLocalStore.version,
            builder: (context, _, __) {
              return ListView(
                controller: _scroll,
                padding: TvReachability.accountPadding,
                children: [
                  const _AccountHeader(),
                  const SizedBox(height: 14),
                  for (var i = 0; i < items.length; i++) ...[
                    _AccountActionCard(
                      node: _nodes[i],
                      item: items[i],
                      onTap: () => _activateItem(i, items[i]),
                      onKey: (node, event) => _rowKey(i, items[i], event),
                    ),
                    if (i < items.length - 1) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  Text('Remote: ↑↓ pilih menu • OK/→ buka • ← navbar • Back kembali ke navbar Akun', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AccountBackIntent extends Intent {
  const _AccountBackIntent();
}

class _AccountItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;
  const _AccountItem(this.icon, this.title, this.subtitle, this.badge, this.onTap);
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(gradient: AppTheme.panelGradient, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.border), boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.045), blurRadius: 18)]),
      child: Row(
        children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: AppTheme.activeGradient, border: Border.all(color: Colors.white.withOpacity(0.18))), child: const Icon(Icons.person_rounded, color: Colors.white, size: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Akun LiveGo', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 5),
                Text('Default: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()} • TV Remote Mode', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
              ],
            ),
          ),
          _MiniStat(value: '${LiveGoLocalStore.history.length}', label: 'Riwayat'),
          const SizedBox(width: 10),
          _MiniStat(value: '${LiveGoLocalStore.favorites.length}', label: 'Favorit'),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSoft)),
      child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10, fontWeight: FontWeight.w800, decoration: TextDecoration.none))]),
    );
  }
}

class _AccountActionCard extends StatelessWidget {
  final FocusNode node;
  final _AccountItem item;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;
  const _AccountActionCard({required this.node, required this.item, required this.onTap, required this.onKey});

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
              constraints: const BoxConstraints(minHeight: 78),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.92), borderRadius: BorderRadius.circular(22), border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1), boxShadow: focused ? [TvFocusStyle.glow(0.07, 5)] : null),
              child: Row(
                children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(gradient: focused ? AppTheme.activeGradient : null, color: focused ? null : AppTheme.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: focused ? Colors.white.withOpacity(0.18) : AppTheme.borderSoft)), child: Icon(item.icon, color: focused ? Colors.white : AppTheme.cyan, size: 25)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      const SizedBox(height: 4),
                      Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: focused ? AppTheme.cyan.withOpacity(0.16) : AppTheme.surface2, borderRadius: BorderRadius.circular(999), border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.38) : AppTheme.borderSoft)), child: Text(item.badge, style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
