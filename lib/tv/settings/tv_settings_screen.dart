import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../core/livego_local_store.dart';
import '../screens/tv_source_manager_screen.dart';
import '../models/tv_zone.dart';
import '../focus/tv_focus_utils.dart';
import '../layout/tv_safe_zone.dart';

part 'tv_settings_models.dart';
part 'tv_settings_widgets.dart';

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
  bool _openingSubscreen = false;

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
    _focusRow(_lastRow, throttle: false);
  }

  bool _focusAndReveal(FocusNode node) {
    if (node.context == null || !node.canRequestFocus) return false;
    if (!node.hasFocus) node.requestFocus();
    _revealFocusedNode(node);
    return true;
  }

  void _revealFocusedNode(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || node.context == null || !node.hasFocus) return;
      try {
        final scrollable = Scrollable.maybeOf(node.context!);
        final renderObject = node.context!.findRenderObject();
        if (scrollable == null || renderObject == null) return;
        final viewport = RenderAbstractViewport.maybeOf(renderObject);
        if (viewport == null) return;

        final position = scrollable.position;
        if (!position.hasPixels || !position.hasViewportDimension) return;

        final leading = viewport.getOffsetToReveal(renderObject, 0.0).offset;
        final trailing = viewport.getOffsetToReveal(renderObject, 1.0).offset;
        final current = position.pixels;
        final visibleBottom = current + position.viewportDimension;

        double? target;
        if (leading < current + TvSafeZone.listTop) {
          target = leading - TvSafeZone.listTop;
        } else if (trailing > visibleBottom - TvSafeZone.listBottom) {
          target = trailing - position.viewportDimension + TvSafeZone.listBottom;
        }

        if (target == null) return;
        final clamped = target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        if ((clamped - current).abs() < 1) return;
        position.jumpTo(clamped);
      } catch (_) {}
    });
  }

  void _focusBack() {
    if (!widget.showBackButton) return;
    _zone = TvZone.nav;
    _focusAndReveal(_backNode);
  }

  bool _focusRow(int index, {bool throttle = true}) {
    if (_rowNodes.isEmpty) return false;
    final target = _safe(index);
    final node = _rowNodes[target];

    _zone = TvZone.settings;
    _lastRow = target;
    return _focusAndReveal(node);
  }

  bool _ignoreRepeatedBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 420) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _goBack() {
    _entryPending = false;
    if (Navigator.of(context).canPop()) Navigator.of(context).maybePop();
  }

  void _handleBack() {
    if (_ignoreRepeatedBack()) return;
    if (widget.onMoveToNav != null) {
      _zone = TvZone.nav;
      _entryPending = false;
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
      final current = _safe(index);
      if (current == 0 && widget.showBackButton) {
        _focusBack();
      } else if (current > 0) {
        _focusRow(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final current = _safe(index);
      if (current < _rowNodes.length - 1) _focusRow(current + 1);
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
      if (_openingSubscreen || !mounted) return;
      _openingSubscreen = true;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TvSourceManagerScreen()))
          .then((_) {
        _openingSubscreen = false;
        if (!mounted) return;
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusRow(_lastRow, throttle: false);
        });
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
    final itemCount = _itemCount;
    if (_rowNodes.length != itemCount) _syncRowNodes(itemCount);

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
          body: DefaultTextStyle.merge(
              style: const TextStyle(decoration: TextDecoration.none),
              child: ListView(
                controller: _scrollController,
                padding: TvSafeZone.settings,
                cacheExtent: TvSafeZone.cacheExtent,
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
    );
  }
}

class _SettingsBackIntent extends Intent {
  const _SettingsBackIntent();
}

