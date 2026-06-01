import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../models/tv_zone.dart';
import '../utils/tv_focus_utils.dart';
import 'tv_settings_screen.dart';
import 'tv_source_manager_screen.dart';

class TvAccountScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final VoidCallback? onBackToNav;
  final VoidCallback? onBackToHome;
  final int focusTicket;

  const TvAccountScreen({
    super.key,
    this.onMoveToNav,
    this.onBackToNav,
    this.onBackToHome,
    this.focusTicket = 0,
  });

  @override
  State<TvAccountScreen> createState() => _TvAccountScreenState();
}

class _TvAccountScreenState extends State<TvAccountScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _topNode = FocusNode(skipTraversal: true, debugLabel: 'tv-account-community');
  final List<FocusNode> _rowNodes = [];

  TvZone _zone = TvZone.list;
  bool _topFocused = true;
  int _lastRow = 0;
  bool _entryPending = false;
  int _lastBackHandledMs = 0;

  List<_AccountSection> get _sections => [
        _AccountSection(
          title: 'Control Center',
          items: [
            _AccountItem(
              icon: Icons.tune_rounded,
              title: 'Pengaturan Tampilan',
              subtitle: 'Mode tampilan, jumlah grid Home TV, dan navigasi layar besar.',
              badge: 'DISPLAY',
              onTap: () => _openSettings(),
            ),
            _AccountItem(
              icon: Icons.layers_rounded,
              title: 'Kelola Sumber Data',
              subtitle: 'Platform, kategori Home TV, batas 6 source, dan indikator server.',
              badge: 'SOURCE',
              onTap: () => _pushScreen(const TvSourceManagerScreen()),
            ),
          ],
        ),
        _AccountSection(
          title: 'Info Aplikasi',
          items: [
            _AccountItem(
              icon: Icons.info_outline_rounded,
              title: 'Tentang LiveGo',
              subtitle: 'Informasi aplikasi, mode TV, dan status sinkron data.',
              badge: 'INFO',
              onTap: () => _showMessage('LiveGo Premium TV • data sinkron dengan mode HP'),
            ),
            _AccountItem(
              icon: Icons.system_update_alt_rounded,
              title: 'Periksa Update',
              subtitle: 'Cek versi terbaru aplikasi dari build GitHub.',
              badge: 'UPDATE',
              onTap: () => _showMessage('Cek update akan disambungkan ke updater setelah fondasi TV stabil.'),
            ),
          ],
        ),
      ];

  int get _itemCount => _sections.fold<int>(0, (sum, section) => sum + section.items.length);

  @override
  void didUpdateWidget(covariant TvAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _focusEntry();
    }
  }

  @override
  void dispose() {
    _topNode.dispose();
    for (final node in _rowNodes) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _syncRowNodes(int count) {
    while (_rowNodes.length < count) {
      _rowNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-account-row-${_rowNodes.length}'));
    }
    while (_rowNodes.length > count) {
      _rowNodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_rowNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = _rowNodes.length - 1;
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

  void _markBackHandled() {
    _lastBackHandledMs = DateTime.now().millisecondsSinceEpoch;
  }

  bool _ignoreRepeatedBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 260) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _handleBack() {
    // Akun harus mundur satu level saja: konten Akun -> navbar Akun.
    // Guard ini mencegah event BACK dari child route (Settings/Source)
    // ikut tembus menjadi Akun -> Home pada satu pencetan remote.
    if (_ignoreRepeatedBack()) return;
    _zone = TvZone.nav;
    if (widget.onBackToNav != null) {
      widget.onBackToNav?.call();
    } else {
      widget.onMoveToNav?.call();
    }
  }

  void _focusEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
  }

  void _tryFocusEntry() {
    if (!mounted || !_entryPending) return;
    _entryPending = false;
    if (_topFocused) {
      _focusTop();
    } else {
      _focusRow(_lastRow);
    }
  }

  void _focusTop() {
    _zone = TvZone.list;
    _topFocused = true;
    tvFocus(_topNode, alignment: 0.04, duration: const Duration(milliseconds: 100));
  }

  void _focusRow(int index) {
    if (_rowNodes.isEmpty) return;
    _zone = TvZone.list;
    _topFocused = false;
    _lastRow = _safe(index);
    tvFocus(_rowNodes[_lastRow], alignment: 0.22, duration: const Duration(milliseconds: 100));
  }

  void _openSettings() => _pushScreen(const TvSettingsScreen());

  void _pushScreen(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _restoreFocusAfterPop());
  }

  void _restoreFocusAfterPop() {
    if (!mounted) return;
    _markBackHandled();
    _zone = TvZone.list;
    _topFocused = false;

    void restore() {
      if (!mounted) return;
      _focusRow(_lastRow);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => restore());
    Future<void>.delayed(const Duration(milliseconds: 120), restore);
    Future<void>.delayed(const Duration(milliseconds: 260), restore);
  }

  KeyEventResult _topKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _zone = TvZone.nav;
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
      _focusRow(_lastRow);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _showMessage('Area komunitas: Telegram, grup update, dan info channel akan ditempatkan di sini.');
      _focusTop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
    return KeyEventResult.ignored;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_topFocused) {
        _focusTop();
      } else {
        _focusRow(_lastRow);
      }
    });
  }

  KeyEventResult _rowKey(int index, _AccountItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      _zone = TvZone.nav;
      _lastRow = index;
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) {
        _focusTop();
      } else {
        _focusRow(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusRow(index < _rowNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
      _lastRow = index;
      item.onTap();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _lastRow = index;
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _syncRowNodes(_itemCount);
    if (_entryPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
    }

    final sectionWidgets = <Widget>[];
    var cursor = 0;
    for (final section in _sections) {
      final rows = <Widget>[];
      for (final item in section.items) {
        final index = cursor++;
        rows.add(_ActionRow(
          node: _rowNodes[index],
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          badge: item.badge,
          onTap: () {
            _lastRow = index;
            item.onTap();
          },
          onKey: (node, event) => _rowKey(index, item, event),
          isLast: item == section.items.last,
        ));
      }
      sectionWidgets.addAll([
        _SectionTitle(section.title),
        _Panel(children: rows),
        const SizedBox(height: 14),
      ]);
    }

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
              padding: const EdgeInsets.fromLTRB(16, 16, 26, 26),
              children: [
                ListenableBuilder(
                  listenable: _topNode,
                  builder: (context, _) {
                    return Focus(
                      focusNode: _topNode,
                      skipTraversal: true,
                      autofocus: false,
                      onKeyEvent: _topKey,
                      child: InkWell(
                        canRequestFocus: false,
                        borderRadius: BorderRadius.circular(22),
                        focusColor: Colors.transparent,
                        onTap: () => _showMessage('Area komunitas: Telegram, grup update, dan info channel akan ditempatkan di sini.'),
                        child: _CommunityBanner(focused: _topNode.hasFocus),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const _ProfileHeader(),
                const SizedBox(height: 10),
                _StatsRow(
                  history: LiveGoLocalStore.history.length,
                  favorites: LiveGoLocalStore.favorites.length,
                  downloads: LiveGoLocalStore.downloads.length,
                ),
                const SizedBox(height: 14),
                ...sectionWidgets,
                Text(
                  _zone == TvZone.list ? 'Remote: ↑↓ pilih item • OK/→ buka • ← navbar • Back ke navbar Akun' : '',
                  style: TextStyle(color: AppTheme.textSoft.withOpacity(0.70), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
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

class _AccountSection {
  final String title;
  final List<_AccountItem> items;

  const _AccountSection({required this.title, required this.items});
}

class _AccountItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _AccountItem({required this.icon, required this.title, required this.subtitle, required this.badge, required this.onTap});
}


class _CommunityBanner extends StatelessWidget {
  final bool focused;
  const _CommunityBanner({this.focused = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surface2, AppTheme.bgDeep],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: focused ? AppTheme.whiteGlow : AppTheme.border, width: focused ? 2 : 1),
        boxShadow: focused
            ? [
                BoxShadow(color: AppTheme.cyan.withOpacity(0.18), blurRadius: 24),
                BoxShadow(color: AppTheme.purple.withOpacity(0.10), blurRadius: 32),
              ]
            : [BoxShadow(color: AppTheme.cyan.withOpacity(0.08), blurRadius: 28)],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppTheme.surface2,
              border: Border.all(color: AppTheme.cyan.withOpacity(0.30)),
            ),
            child: const Icon(Icons.groups_rounded, color: AppTheme.whiteGlow, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Komunitas LiveGo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                SizedBox(height: 4),
                Text('Area banner untuk Telegram, grup update, alamat channel, dan info komunitas.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.30)),
            ),
            child: const Text('SOON', style: TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.panelGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppTheme.activeGradient,
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Akun LiveGo', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 5),
                Text(
                  'Default: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()} • TV Remote Mode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.35)),
            ),
            child: const Text('SYNC DATA', style: TextStyle(color: AppTheme.whiteGlow, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6, decoration: TextDecoration.none)),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int history;
  final int favorites;
  final int downloads;

  const _StatsRow({required this.history, required this.favorites, required this.downloads});

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.88),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.cyan, size: 20),
            const SizedBox(width: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .3, decoration: TextDecoration.none)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat('$history', 'RIWAYAT', Icons.history_rounded),
        const SizedBox(width: 10),
        _stat('$favorites', 'FAVORIT', Icons.favorite_rounded),
        const SizedBox(width: 10),
        _stat('$downloads', 'DOWNLOAD', Icons.download_rounded),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final FocusNode node;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;
  final bool isLast;

  const _ActionRow({
    required this.node,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
    required this.onKey,
    required this.isLast,
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
            borderRadius: BorderRadius.circular(18),
            focusColor: Colors.transparent,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: focused ? AppTheme.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2),
                    boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.14), blurRadius: 14)] : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white10)),
                        child: Icon(icon, color: Colors.white, size: 21),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                            const SizedBox(height: 3),
                            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.3, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: focused ? AppTheme.surface3 : Colors.white.withOpacity(0.045),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.55) : Colors.white10),
                        ),
                        child: Text(badge, style: TextStyle(color: focused ? AppTheme.whiteGlow : Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .4, decoration: TextDecoration.none)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: focused ? AppTheme.cyan : Colors.white30, size: 21),
                    ],
                  ),
                ),
                if (!isLast) const Divider(color: AppTheme.border, height: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, decoration: TextDecoration.none)),
    );
  }
}
