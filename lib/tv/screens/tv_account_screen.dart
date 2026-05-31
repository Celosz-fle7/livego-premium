import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../models/tv_zone.dart';
import '../utils/tv_focus_utils.dart';
import 'tv_settings_screen.dart';

class TvAccountScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final int focusTicket;

  const TvAccountScreen({
    super.key,
    this.onMoveToNav,
    this.focusTicket = 0,
  });

  @override
  State<TvAccountScreen> createState() => _TvAccountScreenState();
}

class _TvAccountScreenState extends State<TvAccountScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _rowNodes = [];

  TvZone _zone = TvZone.list;
  int _lastRow = 0;
  bool _entryPending = false;

  List<_AccountSection> get _sections => [
        _AccountSection(
          title: 'Koleksi Cepat',
          items: [
            _AccountItem(icon: Icons.history_rounded, title: 'Riwayat', subtitle: 'Lanjutkan tontonan terakhir yang sudah dibuka.', onTap: () {}),
            _AccountItem(icon: Icons.favorite_border_rounded, title: 'Favorit', subtitle: 'Buka daftar judul yang Anda simpan.', onTap: () {}),
            _AccountItem(icon: Icons.download_rounded, title: 'Download', subtitle: 'Lihat antrean dan episode yang tersimpan.', onTap: () {}),
            _AccountItem(
              icon: Icons.settings_rounded,
              title: 'Pengaturan',
              subtitle: 'Atur tampilan, player, subtitle, dan source aktif.',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TvSettingsScreen()));
              },
            ),
          ],
        ),
        _AccountSection(
          title: 'Aplikasi & Dukungan',
          items: [
            _AccountItem(icon: Icons.system_update_alt_rounded, title: 'Periksa Pembaruan', subtitle: 'Cek versi terbaru LiveGo Premium.', onTap: () {}),
            _AccountItem(icon: Icons.share_rounded, title: 'Dukung LiveGo', subtitle: 'Bantu maintenance dan eksperimen fitur baru.', onTap: () {}),
            _AccountItem(icon: Icons.send_rounded, title: 'Kirim Feedback', subtitle: 'Laporkan bug, source, atau usulan fitur.', onTap: () {}),
            _AccountItem(icon: Icons.help_outline_rounded, title: 'Bantuan', subtitle: 'Panduan pemakaian aplikasi di Android TV.', onTap: () {}),
          ],
        ),
      ];

  int get _itemCount => _sections.fold<int>(0, (sum, section) => sum + section.items.length);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TvAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusTicket != widget.focusTicket) {
      _focusEntry();
    }
  }

  @override
  void dispose() {
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

  void _focusEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
  }

  void _tryFocusEntry() {
    if (!mounted || !_entryPending || _rowNodes.isEmpty) return;
    _entryPending = false;
    _focusRow(_lastRow);
  }

  void _focusRow(int index) {
    if (_rowNodes.isEmpty) return;
    _zone = TvZone.list;
    _lastRow = _safe(index);
    tvFocus(_rowNodes[_lastRow], alignment: 0.30);
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
      _focusRow(index == 0 ? 0 : index - 1);
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
        const SizedBox(height: 18),
      ]);
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 24, 30, 30),
      children: [
        const _ProfileHeader(),
        const SizedBox(height: 18),
        ...sectionWidgets,
        Text(
          _zone == TvZone.list ? 'Remote: ↑↓ pilih item • OK/→ buka • ← kembali ke navbar' : '',
          style: TextStyle(color: AppTheme.textSoft.withOpacity(0.70), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
        ),
      ],
    );
  }
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
  final VoidCallback onTap;

  const _AccountItem({required this.icon, required this.title, required this.subtitle, required this.onTap});
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0B2634), Color(0xFF080D17)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E3850)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.65)),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Penggemar LiveGO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 5),
                Text(
                  'Default: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()}',
                  style: const TextStyle(color: AppTheme.textSoft, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        ],
      ),
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
        color: const Color(0xFF09111E).withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1A2D43)),
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
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;
  final bool isLast;

  const _ActionRow({
    required this.node,
    required this.icon,
    required this.title,
    required this.subtitle,
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
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            focusColor: Colors.transparent,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  height: 74,
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: focused ? const Color(0xFF102F45) : Colors.transparent,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2),
                    boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.16), blurRadius: 16)] : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: const Color(0xFF102033), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                        child: Icon(icon, color: Colors.white, size: 25),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                            const SizedBox(height: 3),
                            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 27),
                    ],
                  ),
                ),
                if (!isLast) const Divider(color: Color(0xFF24344A), height: 1),
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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1, decoration: TextDecoration.none)),
    );
  }
}
