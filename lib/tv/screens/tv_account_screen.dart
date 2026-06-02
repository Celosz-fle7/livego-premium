import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../theme/tv_focus_style.dart';
import '../utils/tv_focus_utils.dart';
import 'tv_settings_screen.dart';
import 'tv_source_manager_screen.dart';

class TvAccountScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final VoidCallback? onBackToNav;
  final ValueChanged<int>? onOpenNavIndex;
  final int focusTicket;

  const TvAccountScreen({
    super.key,
    this.onMoveToNav,
    this.onBackToNav,
    this.onOpenNavIndex,
    this.focusTicket = 0,
  });

  @override
  State<TvAccountScreen> createState() => _TvAccountScreenState();
}

class _TvAccountScreenState extends State<TvAccountScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _nodes = [];

  int _lastIndex = 0;
  int _lastBackHandledMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusRow(_lastIndex);
    });
  }

  List<_AccountItem> get _items => [
        _AccountItem(
          icon: Icons.layers_rounded,
          title: 'Kelola Sumber Data',
          subtitle: 'Atur Anichin, Dobda, bahasa, kategori, dan platform aktif.',
          badge: 'SOURCE',
          onTap: () => _pushScreen(const TvSourceManagerScreen()),
        ),
        _AccountItem(
          icon: Icons.history_rounded,
          title: 'Riwayat Tontonan',
          subtitle: 'Buka histori tontonan dari navbar TV.',
          badge: '${LiveGoLocalStore.history.length}',
          onTap: () => widget.onOpenNavIndex?.call(1),
        ),
        _AccountItem(
          icon: Icons.favorite_rounded,
          title: 'Favorit',
          subtitle: 'Daftar konten yang kamu simpan.',
          badge: '${LiveGoLocalStore.favorites.length}',
          onTap: () => widget.onOpenNavIndex?.call(3),
        ),
        _AccountItem(
          icon: Icons.download_rounded,
          title: 'Download',
          subtitle: 'Kelola unduhan dan episode offline.',
          badge: '${LiveGoLocalStore.downloads.length}',
          onTap: () => widget.onOpenNavIndex?.call(4),
        ),
        _AccountItem(
          icon: Icons.tune_rounded,
          title: 'Pengaturan Tampilan',
          subtitle: 'Mode tampilan, grid, ukuran poster, dan preferensi layar.',
          badge: 'DISPLAY',
          onTap: () => _pushScreen(const TvSettingsScreen()),
        ),
        _AccountItem(
          icon: Icons.info_outline_rounded,
          title: 'Tentang Aplikasi',
          subtitle: 'Informasi LiveGo Premium, mode TV, dan status data.',
          badge: 'INFO',
          onTap: () => _showMessage('LiveGo Premium TV • data sinkron dengan mode HP'),
        ),
        _AccountItem(
          icon: Icons.system_update_alt_rounded,
          title: 'Periksa Update',
          subtitle: 'Cek versi terbaru dari build GitHub.',
          badge: 'UPDATE',
          onTap: () => _showMessage('Cek update akan disambungkan setelah fondasi TV stabil.'),
        ),
      ];

  @override
  void didUpdateWidget(covariant TvAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _focusRow(_lastIndex);
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _scrollController.dispose();
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
    if (value < 0) return 0;
    final max = _nodes.length - 1;
    if (value > max) return max;
    return value;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool _ignoreRepeatedBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 260) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _handleBack() {
    if (_ignoreRepeatedBack()) return;
    widget.onBackToNav?.call();
  }

  void _focusRow(int index) {
    if (_nodes.isEmpty) return;
    _lastIndex = _safe(index);
    if (mounted) setState(() {});

    void request() {
      if (!mounted || _nodes.isEmpty) return;
      tvFocus(_nodes[_lastIndex], alignment: 0.24, duration: TvFocusStyle.fast);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => request());
    Future<void>.delayed(TvFocusStyle.fast, request);
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _restoreFocusAfterPop());
  }

  void _restoreFocusAfterPop() {
    if (!mounted) return;
    _lastBackHandledMs = DateTime.now().millisecondsSinceEpoch;
    _focusRow(_lastIndex);
    Future<void>.delayed(const Duration(milliseconds: 110), () {
      if (mounted) _focusRow(_lastIndex);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface2,
          duration: const Duration(seconds: 2),
        ),
      );
    _focusRow(_lastIndex);
  }

  KeyEventResult _rowKey(int index, _AccountItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      _focusRow(index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusRow(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
      _lastIndex = _safe(index);
      item.onTap();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _handleBack();
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
            _handleBack();
            return null;
          }),
        },
        child: ValueListenableBuilder<int>(
          valueListenable: LiveGoLocalStore.version,
          builder: (context, _, __) {
            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(22, 18, 30, 28),
              children: [
                const _AccountHeader(),
                const SizedBox(height: 14),
                for (var i = 0; i < items.length; i++) ...[
                  _AccountActionCard(
                    node: _nodes[i],
                    item: items[i],
                    onTap: () {
                      _lastIndex = i;
                      items[i].onTap();
                    },
                    onKey: (node, event) => _rowKey(i, items[i], event),
                  ),
                  if (i < items.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                Text(
                  'Remote: ↑↓ pilih menu • OK/→ buka • ← tampilkan navbar • Back kembali ke navbar Akun',
                  style: TextStyle(
                    color: AppTheme.textSoft.withOpacity(0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            );
          },
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

  const _AccountItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.panelGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.07), blurRadius: 26)],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: AppTheme.activeGradient,
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Akun LiveGo',
                  style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                ),
                const SizedBox(height: 5),
                Text(
                  'Default: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()} • TV Remote Mode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
          _MiniStat(value: '${LiveGoLocalStore.history.length}', label: 'Riwayat'),
          const SizedBox(width: 10),
          _MiniStat(value: '${LiveGoLocalStore.favorites.length}', label: 'Favorit'),
          const SizedBox(width: 10),
          _MiniStat(value: '${LiveGoLocalStore.downloads.length}', label: 'Download'),
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
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _AccountActionCard extends StatelessWidget {
  final FocusNode node;
  final _AccountItem item;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

  const _AccountActionCard({
    required this.node,
    required this.item,
    required this.onTap,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          autofocus: false,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              height: 78,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: focused
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [TvFocusStyle.focusBlue.withOpacity(0.24), AppTheme.purple.withOpacity(0.14)],
                      )
                    : null,
                color: focused ? null : AppTheme.surface.withOpacity(0.86),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: focused ? TvFocusStyle.focusBlue : AppTheme.border, width: focused ? 2.4 : 1),
                boxShadow: focused
                    ? [
                        TvFocusStyle.glow(0.30, 22),
                        BoxShadow(color: AppTheme.purple.withOpacity(0.10), blurRadius: 34),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft),
                    ),
                    child: Icon(item.icon, color: focused ? AppTheme.whiteGlow : TvFocusStyle.focusBlue, size: 25),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    constraints: const BoxConstraints(minWidth: 58),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: focused ? AppTheme.whiteGlow.withOpacity(0.55) : AppTheme.cyan.withOpacity(0.25)),
                    ),
                    child: Text(
                      item.badge,
                      style: TextStyle(
                        color: focused ? AppTheme.whiteGlow : AppTheme.cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded, color: focused ? AppTheme.whiteGlow : Colors.white38, size: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
