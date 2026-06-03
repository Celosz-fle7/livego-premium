import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../core/livego_local_store.dart';
import '../screens/tv_source_manager_screen.dart';
import '../models/tv_zone.dart';
import '../utils/tv_focus_utils.dart';

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
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _rowNodes = [];
  late final FocusNode _backNode;

  TvZone _zone = TvZone.settings;
  int _lastRow = 0;
  bool _entryPending = false;
  int _lastBackHandledMs = 0;

  List<_SettingsSection> get _sections => [
        _SettingsSection(
          title: 'Tampilan & Navigasi',
          description: 'Pilih antarmuka yang paling cocok. Mode Auto mengikuti perangkat saat aplikasi dibuka.',
          items: [
            _SettingItem.radio(kind: _SettingKind.layoutAuto, title: 'Otomatis (Ikuti Hardware)', active: LiveGoSettings.layoutMode == 'Auto'),
            _SettingItem.radio(kind: _SettingKind.layoutMobile, title: 'Smartphone / Tablet (Android)', active: LiveGoSettings.layoutMode == 'Mobile'),
            _SettingItem.radio(kind: _SettingKind.layoutTv, title: 'Android TV (Leanback Style)', active: LiveGoSettings.layoutMode == 'TV'),
          ],
        ),
        _SettingsSection(
          title: 'Tampilan Home',
          items: [
            _SettingItem.tile(
              kind: _SettingKind.tvGrid,
              icon: Icons.grid_view_rounded,
              title: 'Jumlah Grid Home TV',
              subtitle: 'LEFT kurang, RIGHT/OK tambah. Nilai ini langsung mengatur jumlah kolom poster Home TV.',
              value: '${LiveGoSettings.tvHomeGrid}',
              showGridBar: true,
            ),
          ],
        ),
        _SettingsSection(
          title: 'Sumber & Izin',
          items: [
            _SettingItem.tile(
              kind: _SettingKind.downloadNotice,
              icon: Icons.info_rounded,
              title: 'Notifikasi Unduhan',
              subtitle: 'Toggle preferensi unduhan melalui remote.',
              value: LiveGoSettings.downloadWifiOnly ? 'Wi-Fi' : 'Bebas',
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
      if (mounted) _focusEntry();
    });
  }

  @override
  void didUpdateWidget(covariant TvSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) _focusEntry();
  }

  @override
  void dispose() {
    for (final node in _rowNodes) {
      node.dispose();
    }
    _backNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncRowNodes(int count) {
    while (_rowNodes.length < count) {
      _rowNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-settings-row-${_rowNodes.length}'));
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

  void _focusEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
  }

  void _tryFocusEntry() {
    if (!mounted || !_entryPending || _rowNodes.isEmpty) return;
    _entryPending = false;
    _focusRow(_lastRow);
  }

  void _focusBack() {
    if (!widget.showBackButton) return;
    _zone = TvZone.nav;
    tvFocus(_backNode, alignment: 0.10);
  }

  void _focusRow(int index) {
    if (_rowNodes.isEmpty) return;
    _zone = TvZone.settings;
    _lastRow = _safe(index);
    tvFocusComfort(_rowNodes[_lastRow]);
  }

  bool _ignoreRepeatedBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 420) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) Navigator.of(context).maybePop();
  }

  void _handleBack() {
    if (_ignoreRepeatedBack()) return;
    if (widget.onMoveToNav != null) {
      _zone = TvZone.nav;
      widget.onMoveToNav?.call();
      return;
    }
    _goBack();
  }

  KeyEventResult _backKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      _focusRow(_lastRow);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && widget.onMoveToNav != null) {
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _goBack();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _rowKey(int index, _SettingItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0 && widget.showBackButton) {
        _focusBack();
      } else {
        _focusRow(index == 0 ? 0 : index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusRow(index < _rowNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _lastRow = index;
      if (item.kind == _SettingKind.tvGrid) {
        _adjustTvGrid(-1);
        _focusRow(index);
        return KeyEventResult.handled;
      }
      if (item.kind == _SettingKind.drmMode) {
        _cycleDrm(-1);
        _focusRow(index);
        return KeyEventResult.handled;
      }
      if (widget.onMoveToNav != null) {
        widget.onMoveToNav?.call();
      } else if (widget.showBackButton) {
        _focusBack();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _lastRow = index;
      if (item.kind == _SettingKind.tvGrid) {
        _adjustTvGrid(1);
      } else if (item.kind == _SettingKind.drmMode) {
        _cycleDrm(1);
      } else {
        _activate(item.kind);
      }
      _focusRow(index);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _lastRow = index;
      _activate(item.kind);
      _focusRow(index);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _persistSettings() {
    LiveGoLocalStore.saveSettings();
  }

  void _adjustTvGrid(int delta) {
    setState(() => LiveGoSettings.setTvHomeGrid(LiveGoSettings.tvHomeGrid + delta));
    _persistSettings();
  }

  String _nextDrm(int delta) {
    const values = ['Auto', 'Paksa L3', 'Nonaktifkan Paksa L3'];
    final current = values.indexOf(LiveGoSettings.drmMode);
    final base = current < 0 ? 0 : current;
    final next = (base + delta) % values.length;
    return values[next < 0 ? next + values.length : next];
  }

  void _cycleDrm(int delta) {
    setState(() => LiveGoSettings.drmMode = _nextDrm(delta));
    _persistSettings();
  }

  void _activate(_SettingKind kind) {
    if (kind == _SettingKind.sourceManager) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TvSourceManagerScreen()))
          .then((_) {
        if (!mounted) return;
        setState(() {});
        void restore() {
          if (mounted) _focusRow(_lastRow);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => restore());
        Future<void>.delayed(const Duration(milliseconds: 120), restore);
      });
      return;
    }

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
          LiveGoSettings.drmMode = _nextDrm(1);
          break;
        case _SettingKind.tvGrid:
          LiveGoSettings.setTvHomeGrid(LiveGoSettings.tvHomeGrid + 1);
          break;
        case _SettingKind.sourceManager:
          break;
        case _SettingKind.downloadNotice:
          LiveGoSettings.downloadWifiOnly = !LiveGoSettings.downloadWifiOnly;
          break;
        case _SettingKind.reset:
          LiveGoSettings.reset();
          break;
      }
    });
    _persistSettings();
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
        final rowIndex = cursor++;
        rows.add(_FocusedSettingRow(
          node: _rowNodes[rowIndex],
          item: item,
          onKey: (node, event) => _rowKey(rowIndex, item, event),
          onTap: () {
            _lastRow = rowIndex;
            _activate(item.kind);
            _focusRow(rowIndex);
          },
          isLast: item == section.items.last,
        ));
      }
      sectionWidgets.addAll([
        _SectionTitle(section.title),
        const SizedBox(height: 10),
        _SettingsCard(description: section.description, children: rows),
        const SizedBox(height: 16),
      ]);
    }

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.goBack): _SettingsBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _SettingsBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _SettingsBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SettingsBackIntent: CallbackAction<_SettingsBackIntent>(onInvoke: (_) {
            _handleBack();
            return null;
          }),
        },
        child: Scaffold(
          backgroundColor: AppTheme.bgDeep,
          body: SafeArea(
            top: true,
            bottom: false,
            left: false,
            right: false,
            child: DefaultTextStyle.merge(
              style: const TextStyle(decoration: TextDecoration.none),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(48, 24, 48, 200),
                children: [
                  _Header(
                    showBackButton: widget.showBackButton,
                    backNode: _backNode,
                    onBackKey: _backKey,
                    onBackTap: _goBack,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      _HeaderPill('Display'),
                      SizedBox(width: 10),
                      _HeaderPill('Source'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...sectionWidgets,
                  Text(
                    _zone == TvZone.settings ? 'Remote: ↑↓ pilih item • OK/→ ubah nilai • ←/Back kembali' : '',
                    style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsBackIntent extends Intent {
  const _SettingsBackIntent();
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
  sourceManager,
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
  final VoidCallback onBackTap;

  const _Header({required this.showBackButton, required this.backNode, required this.onBackKey, required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            _BackButton(node: backNode, onKey: onBackKey, onTap: onBackTap),
            const SizedBox(width: 14),
          ],
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.activeGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('CONTROL CENTER', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2, decoration: TextDecoration.none)),
                SizedBox(height: 10),
                Text('Pengaturan LiveGo', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                SizedBox(height: 8),
                Text('Rapikan mode tampilan, source, izin, dan cache dari satu tempat.', style: TextStyle(color: AppTheme.textSoft, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final FocusNode node;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _BackButton({required this.node, required this.onKey, required this.onTap});

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
            borderRadius: BorderRadius.circular(16),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: focused ? AppTheme.surface3 : AppTheme.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: focused ? AppTheme.cyan : Colors.white10, width: focused ? 2 : 1),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String text;
  const _HeaderPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, decoration: TextDecoration.none)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, decoration: TextDecoration.none)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Text(description!, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, height: 1.35, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            ),
            const SizedBox(height: 4),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _FocusedSettingRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        final accent = item.danger ? AppTheme.danger : AppTheme.cyan;
        final isRadio = item.style == _SettingItemStyle.radio;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          autofocus: false,
          onKeyEvent: onKey,
          child: InkWell(
              canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            focusColor: Colors.transparent,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: EdgeInsets.symmetric(horizontal: isRadio ? 12 : 13, vertical: isRadio ? 11 : 9),
                  decoration: BoxDecoration(
                    color: focused ? AppTheme.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: focused ? accent : Colors.transparent, width: 2),
                    boxShadow: focused ? [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 10)] : null,
                  ),
                  child: isRadio ? _RadioContent(item: item, focused: focused) : _TileContent(item: item, focused: focused, accent: accent),
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

class _RadioContent extends StatelessWidget {
  final _SettingItem item;
  final bool focused;

  const _RadioContent({required this.item, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(item.active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: item.active || focused ? AppTheme.cyan : AppTheme.textSoft, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Text(item.title, style: TextStyle(color: item.active || focused ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 15.5, decoration: TextDecoration.none)),
        ),
        if (item.active) const Text('AKTIF', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11.5, decoration: TextDecoration.none)),
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.surface3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: focused ? accent.withOpacity(0.85) : AppTheme.border),
          ),
          child: Icon(item.icon, color: item.danger ? accent : Colors.white, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: TextStyle(color: item.danger ? accent : Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              const SizedBox(height: 5),
              Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              if (item.showGridBar) ...[
                const SizedBox(height: 12),
                _TvGridStepper(value: LiveGoSettings.tvHomeGrid, focused: focused),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (item.switchValue != null)
          _SwitchPill(value: item.switchValue!, focused: focused)
        else if (item.showGridBar)
          Text('←  ${LiveGoSettings.tvHomeGrid}  →', style: TextStyle(color: focused ? accent : AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 12.5, decoration: TextDecoration.none))
        else
          Text(item.value, style: TextStyle(color: focused ? accent : (item.danger ? accent : AppTheme.cyan), fontWeight: FontWeight.w900, fontSize: 12.5, decoration: TextDecoration.none)),
        const SizedBox(width: 12),
        Icon(item.danger ? Icons.arrow_forward_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? accent : Colors.white38, size: 26),
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
      width: 58,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? AppTheme.cyan.withOpacity(focused ? 0.95 : 0.78) : AppTheme.surface3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? Colors.white70 : Colors.transparent),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }
}


class _TvGridStepper extends StatelessWidget {
  final int value;
  final bool focused;

  const _TvGridStepper({required this.value, required this.focused});

  @override
  Widget build(BuildContext context) {
    Widget box(String text, {bool active = false}) {
      return Container(
        width: active ? 56 : 36,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active || focused ? AppTheme.cyan.withOpacity(0.75) : Colors.white12),
        ),
        child: Text(text, style: TextStyle(color: active || focused ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 12, decoration: TextDecoration.none)),
      );
    }

    return Row(
      children: [
        box('-'),
        const SizedBox(width: 8),
        box('$value', active: true),
        const SizedBox(width: 8),
        box('+'),
        const SizedBox(width: 14),
        Expanded(child: _GridPreview(value: value)),
      ],
    );
  }
}

class _GridPreview extends StatelessWidget {
  final int value;
  const _GridPreview({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(10, (i) {
        final active = i < value;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i == 9 ? 0 : 4),
            decoration: BoxDecoration(
              color: active ? AppTheme.cyan : AppTheme.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
