import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../focus/tv_scroll_engine.dart';

class TvSettingsScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onMoveToNav;
  final int focusTicket;

  const TvSettingsScreen({
    super.key,
    this.showBackButton = true,
    this.onMoveToNav,
    this.focusTicket = 0,
  });

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  final List<FocusNode> _rowNodes = [];
  late final FocusNode _backNode;
  int _row = 0;

  List<_SettingsSection> get _sections => [
        _SettingsSection(
          title: 'Tampilan & Navigasi',
          description: 'Pilih antarmuka yang paling cocok. Mode Auto mengikuti perangkat saat aplikasi dibuka.',
          items: [
            _SettingItem.radio(
              kind: _SettingKind.layoutAuto,
              title: 'Otomatis (Ikuti Hardware)',
              active: LiveGoSettings.layoutMode == 'Auto',
            ),
            _SettingItem.radio(
              kind: _SettingKind.layoutMobile,
              title: 'Smartphone / Tablet (Android)',
              active: LiveGoSettings.layoutMode == 'Mobile',
            ),
            _SettingItem.radio(
              kind: _SettingKind.layoutTv,
              title: 'Android TV (Leanback Style)',
              active: LiveGoSettings.layoutMode == 'TV',
            ),
          ],
        ),
        _SettingsSection(
          title: 'Player',
          items: [
            _SettingItem.tile(
              kind: _SettingKind.backgroundPoster,
              icon: Icons.image_rounded,
              title: 'Tampilkan Background Poster',
              subtitle: 'Poster menjadi ambience di halaman detail dan player.',
              value: LiveGoSettings.backgroundPoster ? 'ON' : 'OFF',
              switchValue: LiveGoSettings.backgroundPoster,
            ),
            _SettingItem.tile(
              kind: _SettingKind.cachePlayback,
              icon: Icons.sync_rounded,
              title: 'Gunakan Cache Playback',
              subtitle: 'Simpan potongan stream sementara agar perpindahan lebih stabil.',
              value: LiveGoSettings.cachePlayback ? 'ON' : 'OFF',
              switchValue: LiveGoSettings.cachePlayback,
            ),
            _SettingItem.tile(
              kind: _SettingKind.manualRotate,
              icon: Icons.screen_rotation_rounded,
              title: 'Tampilkan Tombol Rotasi Manual',
              subtitle: 'Tampilkan kontrol rotasi manual saat menonton.',
              value: LiveGoSettings.manualRotateButton ? 'ON' : 'OFF',
              switchValue: LiveGoSettings.manualRotateButton,
            ),
            _SettingItem.tile(
              kind: _SettingKind.drmMode,
              icon: Icons.lock_rounded,
              title: 'Kompatibilitas Widevine DRM',
              subtitle: 'Mode saat ini: ${LiveGoSettings.drmMode}',
              value: 'ATUR',
            ),
          ],
        ),
        _SettingsSection(
          title: 'Tampilan Home',
          items: [
            _SettingItem.tile(
              kind: _SettingKind.tvGrid,
              icon: Icons.grid_view_rounded,
              title: 'Jumlah Grid Home',
              subtitle: 'Tekan OK atau kanan untuk mengatur jumlah poster TV. Batas TV sampai 10 grid.',
              value: '${LiveGoSettings.tvHomeGrid}',
              showGridBar: true,
            ),
          ],
        ),
        _SettingsSection(
          title: 'Sumber & Izin',
          items: [
            _SettingItem.tile(
              kind: _SettingKind.defaultPlatform,
              icon: Icons.layers_rounded,
              title: 'Kelola Sumber Data',
              subtitle: 'Pilih platform Home, kategori, dan cek status server.',
              value: LiveGoSettings.defaultPlatform.toUpperCase(),
            ),
            _SettingItem.tile(
              kind: _SettingKind.downloadNotice,
              icon: Icons.info_rounded,
              title: 'Kelola Notifikasi Unduhan',
              subtitle: 'Belum aktif. Aktifkan lagi agar progress unduhan mudah dipantau.',
              value: LiveGoSettings.downloadWifiOnly ? 'AKTIFKAN' : 'AKTIF',
            ),
          ],
        ),
        _SettingsSection(
          title: 'Perawatan',
          items: [
            _SettingItem.tile(
              kind: _SettingKind.reset,
              icon: Icons.delete_rounded,
              title: 'Hapus Semua Cache',
              subtitle: 'Bersihkan cache streaming dan gambar agar ruang penyimpanan lega.',
              value: 'RESET',
              danger: true,
            ),
          ],
        ),
      ];

  int get _itemCount => _sections.fold<int>(0, (sum, section) => sum + section.items.length);

  @override
  void initState() {
    super.initState();
    _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-settings-back');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRowNodes(_itemCount);
      _focusRow(0);
    });
  }

  @override
  void didUpdateWidget(covariant TvSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusTicket != widget.focusTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncRowNodes(_itemCount);
        _focusRow(_row);
      });
    }
  }

  @override
  void dispose() {
    for (final node in _rowNodes) {
      node.dispose();
    }
    _backNode.dispose();
    super.dispose();
  }

  void _syncRowNodes(int count) {
    while (_rowNodes.length < count) {
      _rowNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-settings-row-${_rowNodes.length}'));
    }
    while (_rowNodes.length > count) {
      _rowNodes.removeLast().dispose();
    }
    if (_rowNodes.isNotEmpty) _row = _row.clamp(0, _rowNodes.length - 1);
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

  void _focusBack() {
    if (!widget.showBackButton) return;
    focusAndReveal(_backNode, alignment: 0.05);
  }

  void _focusRow(int index) {
    if (_rowNodes.isEmpty) return;
    final safe = index.clamp(0, _rowNodes.length - 1);
    _row = safe;
    focusAndReveal(_rowNodes[safe], alignment: 0.30);
  }

  void _moveToNav() {
    if (widget.onMoveToNav != null) {
      widget.onMoveToNav!.call();
      return;
    }
    _focusBack();
  }

  KeyEventResult _backKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
      _focusRow(0);
      return KeyEventResult.handled;
    }

    if (_isSelect(key) || _isBack(key)) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _rowKey(int index, _SettingItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) {
        if (widget.showBackButton) _focusBack();
      } else {
        _focusRow(index - 1);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (index < _rowNodes.length - 1) _focusRow(index + 1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNav();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
      _activate(item.kind);
      return KeyEventResult.handled;
    }

    if (_isBack(key)) {
      if (widget.showBackButton) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  void _activate(_SettingKind kind) {
    setState(() {
      switch (kind) {
        case _SettingKind.layoutAuto:
          LiveGoSettings.layoutMode = 'Auto';
          break;
        case _SettingKind.layoutMobile:
          LiveGoSettings.layoutMode = 'Mobile';
          break;
        case _SettingKind.layoutTv:
          LiveGoSettings.layoutMode = 'TV';
          break;
        case _SettingKind.backgroundPoster:
          LiveGoSettings.backgroundPoster = !LiveGoSettings.backgroundPoster;
          break;
        case _SettingKind.cachePlayback:
          LiveGoSettings.cachePlayback = !LiveGoSettings.cachePlayback;
          break;
        case _SettingKind.manualRotate:
          LiveGoSettings.manualRotateButton = !LiveGoSettings.manualRotateButton;
          break;
        case _SettingKind.drmMode:
          _cycleString(
            current: LiveGoSettings.drmMode,
            values: const ['Auto', 'Paksa L3', 'Nonaktifkan Paksa L3'],
            setter: (value) => LiveGoSettings.drmMode = value,
          );
          break;
        case _SettingKind.tvGrid:
          LiveGoSettings.setTvHomeGrid(LiveGoSettings.tvHomeGrid >= 10 ? 4 : LiveGoSettings.tvHomeGrid + 1);
          break;
        case _SettingKind.defaultPlatform:
          final values = LiveGoSettings.homePlatforms.isNotEmpty ? LiveGoSettings.homePlatforms : LiveGoSettings.defaultPlatforms;
          if (values.isEmpty) return;
          final index = values.indexOf(LiveGoSettings.defaultPlatform);
          LiveGoSettings.defaultPlatform = values[index < 0 ? 0 : (index + 1) % values.length];
          break;
        case _SettingKind.downloadNotice:
          LiveGoSettings.downloadWifiOnly = !LiveGoSettings.downloadWifiOnly;
          break;
        case _SettingKind.reset:
          LiveGoSettings.reset();
          break;
      }
    });
  }

  void _cycleString({required String current, required List<String> values, required ValueChanged<String> setter}) {
    final index = values.indexOf(current);
    setter(values[index < 0 ? 0 : (index + 1) % values.length]);
  }

  @override
  Widget build(BuildContext context) {
    _syncRowNodes(_itemCount);
    final sectionWidgets = <Widget>[];
    var cursor = 0;

    for (final section in _sections) {
      final rows = <Widget>[];
      for (final item in section.items) {
        final index = cursor++;
        rows.add(
          _FocusedSettingRow(
            node: _rowNodes[index],
            item: item,
            onKey: (node, event) => _rowKey(index, item, event),
            onTap: () => _activate(item.kind),
            isLast: item == section.items.last,
          ),
        );
      }

      sectionWidgets.addAll([
        _SectionTitle(section.title),
        const SizedBox(height: 10),
        _SettingsCard(description: section.description, children: rows),
        const SizedBox(height: 22),
      ]);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 34, 34),
          children: [
            _Header(
              showBackButton: widget.showBackButton,
              backNode: _backNode,
              onBackKey: _backKey,
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                _HeaderPill('Display'),
                SizedBox(width: 10),
                _HeaderPill('Player'),
                SizedBox(width: 10),
                _HeaderPill('Source'),
              ],
            ),
            const SizedBox(height: 20),
            ...sectionWidgets,
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                'Remote: ↑↓ pilih item • OK/→ ubah nilai • ← kembali ke navbar',
                style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection {
  final String title;
  final String? description;
  final List<_SettingItem> items;

  const _SettingsSection({required this.title, required this.items, this.description});
}

enum _SettingKind {
  layoutAuto,
  layoutMobile,
  layoutTv,
  backgroundPoster,
  cachePlayback,
  manualRotate,
  drmMode,
  tvGrid,
  defaultPlatform,
  downloadNotice,
  reset,
}

enum _SettingItemStyle { radio, tile }

class _SettingItem {
  final _SettingKind kind;
  final _SettingItemStyle style;
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool active;
  final bool danger;
  final bool? switchValue;
  final bool showGridBar;

  const _SettingItem._({
    required this.kind,
    required this.style,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.active = false,
    this.danger = false,
    this.switchValue,
    this.showGridBar = false,
  });

  factory _SettingItem.radio({required _SettingKind kind, required String title, required bool active}) {
    return _SettingItem._(
      kind: kind,
      style: _SettingItemStyle.radio,
      icon: active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
      title: title,
      subtitle: '',
      value: active ? 'AKTIF' : '',
      active: active,
    );
  }

  factory _SettingItem.tile({
    required _SettingKind kind,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    bool danger = false,
    bool? switchValue,
    bool showGridBar = false,
  }) {
    return _SettingItem._(
      kind: kind,
      style: _SettingItemStyle.tile,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      danger: danger,
      switchValue: switchValue,
      showGridBar: showGridBar,
    );
  }
}

class _Header extends StatelessWidget {
  final bool showBackButton;
  final FocusNode backNode;
  final FocusOnKeyEventCallback onBackKey;

  const _Header({required this.showBackButton, required this.backNode, required this.onBackKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF09111E).withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1C3148)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 22)],
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            _BackButton(node: backNode, onKey: onBackKey),
            const SizedBox(width: 18),
          ],
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 42),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('CONTROL CENTER', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
                SizedBox(height: 10),
                Text('Pengaturan LiveGo', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Rapikan mode tampilan, player, source, izin, dan cache dari satu tempat.', style: TextStyle(color: AppTheme.textSoft, fontSize: 14, height: 1.35, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final FocusNode node;
  final FocusOnKeyEventCallback onKey;

  const _BackButton({required this.node, required this.onKey});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.node,
      skipTraversal: true,
      onKeyEvent: widget.onKey,
      onFocusChange: (v) => setState(() => _focused = v),
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(16),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF12314A) : const Color(0xFF0A1422),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _focused ? AppTheme.cyan : Colors.white10, width: _focused ? 2 : 1),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String text;
  const _HeaderPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String? description;
  final List<Widget> children;

  const _SettingsCard({required this.children, this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF09111E).withOpacity(0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF1C3148)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Text(description!, style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, height: 1.35, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _FocusedSettingRow extends StatefulWidget {
  final FocusNode node;
  final _SettingItem item;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;
  final bool isLast;

  const _FocusedSettingRow({
    required this.node,
    required this.item,
    required this.onKey,
    required this.onTap,
    required this.isLast,
  });

  @override
  State<_FocusedSettingRow> createState() => _FocusedSettingRowState();
}

class _FocusedSettingRowState extends State<_FocusedSettingRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent = item.danger ? const Color(0xFFFF5C6F) : AppTheme.cyan;
    final isRadio = item.style == _SettingItemStyle.radio;

    return Focus(
      focusNode: widget.node,
      skipTraversal: true,
      onKeyEvent: widget.onKey,
      onFocusChange: (v) => setState(() => _focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        focusColor: Colors.transparent,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: EdgeInsets.symmetric(horizontal: isRadio ? 14 : 16, vertical: isRadio ? 15 : 12),
              decoration: BoxDecoration(
                color: _focused ? const Color(0xFF102F45) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _focused ? accent : Colors.transparent, width: 2),
                boxShadow: _focused ? [BoxShadow(color: accent.withOpacity(0.16), blurRadius: 16)] : null,
              ),
              child: isRadio ? _RadioContent(item: item, focused: _focused) : _TileContent(item: item, focused: _focused, accent: accent),
            ),
            if (!widget.isLast) const Divider(color: Color(0xFF24344A), height: 1),
          ],
        ),
      ),
    );
  }
}

class _RadioContent extends StatelessWidget {
  final _SettingItem item;
  final bool focused;

  const _RadioContent({required this.item, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          item.active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
          color: item.active || focused ? AppTheme.cyan : AppTheme.textSoft,
          size: 28,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            item.title,
            style: TextStyle(color: item.active || focused ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ),
        if (item.active)
          const Text('AKTIF', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    );
  }
}

class _TileContent extends StatelessWidget {
  final _SettingItem item;
  final bool focused;
  final Color accent;

  const _TileContent({required this.item, required this.focused, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF142338),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: focused ? accent.withOpacity(0.85) : const Color(0xFF2B4058)),
          ),
          child: Icon(item.icon, color: item.danger ? accent : Colors.white, size: 27),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(color: item.danger ? accent : Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSoft, fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w700),
              ),
              if (item.showGridBar) ...[
                const SizedBox(height: 12),
                _GridPreview(value: LiveGoSettings.tvHomeGrid),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (item.switchValue != null)
          _SwitchPill(value: item.switchValue!, focused: focused)
        else
          Text(
            item.value,
            style: TextStyle(color: focused ? accent : (item.danger ? accent : AppTheme.cyan), fontWeight: FontWeight.w900, fontSize: 14),
          ),
        const SizedBox(width: 12),
        Icon(item.danger ? Icons.arrow_forward_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? accent : Colors.white38, size: 30),
      ],
    );
  }
}

class _SwitchPill extends StatelessWidget {
  final bool value;
  final bool focused;

  const _SwitchPill({required this.value, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 70,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? AppTheme.cyan.withOpacity(focused ? 0.95 : 0.78) : const Color(0xFF233048),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? Colors.white70 : Colors.transparent),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

class _GridPreview extends StatelessWidget {
  final int value;

  const _GridPreview({required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = ((value - 4) / 6).clamp(0.0, 1.0);
    return Row(
      children: [
        const Text('Grid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        const SizedBox(width: 14),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 5,
              backgroundColor: const Color(0xFF24344A),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text('$value', style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 18)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }
}
