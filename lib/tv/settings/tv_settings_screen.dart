import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../core/livego_local_store.dart';
import '../models/tv_zone.dart';

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
  static const double _topPadding = 24;
  static const double _horizontalPadding = 48;
  static const double _bottomPadding = 220;
  static const double _headerHeight = 96;
  static const double _pillsHeight = 42;
  static const double _sectionTitleHeight = 31;
  static const double _sectionGap = 16;
  static const double _cardVerticalPadding = 6;
  static const double _descriptionHeight = 48;
  static const double _radioRowHeight = 55;
  static const double _tileRowHeight = 82;
  static const double _gridRowHeight = 122;
  static const double _footerHeight = 48;
  static const double _comfortTop = 110;
  static const double _comfortBottom = 180;

  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-settings-root');
  final ScrollController _scrollController = ScrollController();

  TvZone _zone = TvZone.settings;
  int _cursor = 0;
  int _lastBackHandledMs = 0;
  bool _entryPending = false;

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

  List<_SettingItem> get _flatItems {
    final result = <_SettingItem>[];
    for (final section in _sections) {
      result.addAll(section.items);
    }
    return result;
  }

  int get _itemCount => _flatItems.length;

  @override
  void initState() {
    super.initState();
    _scheduleEntry();
  }

  @override
  void didUpdateWidget(covariant TvSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _scheduleEntry();
    }
  }

  @override
  void dispose() {
    _rootNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_entryPending) return;
      _entryPending = false;
      _rootNode.requestFocus();
      _jumpToCursor(_cursor);
    });
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
    if (now - _lastBackHandledMs < 420) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _moveToNav() {
    _zone = TvZone.nav;
    _entryPending = false;
    widget.onMoveToNav?.call();
  }

  void _popScreen() {
    _entryPending = false;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      // This screen uses PopScope(canPop:false) to own TV BACK. maybePop()
      // respects PopScope and can be blocked. Use pop() for the explicit
      // in-screen BACK action, matching Source Manager behavior.
      nav.pop();
    }
  }

  void _handleBack() {
    if (_ignoreRepeatedBack()) return;

    // Match Source Manager behavior: BACK exits the pushed Settings screen in
    // one step. Do not first move to the visual header/back button; that made
    // the screen feel trapped on TV remotes.
    if (widget.onMoveToNav != null && _zone == TvZone.nav) {
      _moveToNav();
      return;
    }
    _popScreen();
  }

  bool _ignoreRepeatActivation(KeyEvent event) {
    if (event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    return _isSelect(key) ||
        _isBack(key) ||
        key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10;
  }

  double _rowHeight(_SettingItem item) {
    if (item.showGridBar) return _gridRowHeight;
    if (item.style == _SettingItemStyle.radio) return _radioRowHeight;
    return _tileRowHeight;
  }

  double _cursorOffset(int cursor) {
    final sections = _sections;
    var offset = _topPadding + _headerHeight + 12 + _pillsHeight + 14;
    var rowIndex = 0;

    for (final section in sections) {
      offset += _sectionTitleHeight + 10;
      offset += _cardVerticalPadding;
      if (section.description != null) offset += _descriptionHeight;

      for (final item in section.items) {
        if (rowIndex == cursor) return offset;
        offset += _rowHeight(item);
        rowIndex++;
      }

      offset += _cardVerticalPadding + _sectionGap;
    }

    return offset;
  }

  void _jumpToCursor(int cursor) {
    if (!_scrollController.hasClients || _itemCount == 0) return;

    final items = _flatItems;
    final safe = cursor.clamp(0, items.length - 1).toInt();
    final position = _scrollController.position;
    final rowTop = _cursorOffset(safe);
    final rowBottom = rowTop + _rowHeight(items[safe]);
    final current = position.pixels;
    final visibleTop = current + _comfortTop;
    final visibleBottom = current + position.viewportDimension - _comfortBottom;

    double? target;
    if (rowTop < visibleTop) {
      target = rowTop - _comfortTop;
    } else if (rowBottom > visibleBottom) {
      target = rowBottom - position.viewportDimension + _comfortBottom;
    }

    if (target == null) return;
    final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if ((clamped - current).abs() < 1) return;
    position.jumpTo(clamped);
  }

  void _moveCursor(int delta) {
    if (_itemCount == 0) return;
    final next = (_cursor + delta).clamp(0, _itemCount - 1).toInt();
    setState(() {
      _zone = TvZone.settings;
      _cursor = next;
    });
    _jumpToCursor(next);
  }

  void _persistSettings() {
    LiveGoLocalStore.saveSettings();
  }

  void _adjustTvGrid(int delta) {
    setState(() => LiveGoSettings.setTvHomeGrid(LiveGoSettings.tvHomeGrid + delta));
    _persistSettings();
    _jumpToCursor(_cursor);
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
    _jumpToCursor(_cursor);
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
    _jumpToCursor(_cursor);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_ignoreRepeatActivation(event)) return KeyEventResult.handled;

    final key = event.logicalKey;

    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }

    if (_zone == TvZone.nav) {
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
        setState(() => _zone = TvZone.settings);
        _jumpToCursor(_cursor);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (widget.onMoveToNav != null) {
          _moveToNav();
        } else {
          _popScreen();
        }
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _handleBack();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    final items = _flatItems;
    if (items.isEmpty) return KeyEventResult.handled;
    final item = items[_cursor.clamp(0, items.length - 1).toInt()];

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_cursor == 0 && widget.showBackButton) {
        setState(() => _zone = TvZone.nav);
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      } else {
        _moveCursor(-1);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (item.kind == _SettingKind.tvGrid) {
        _adjustTvGrid(-1);
      } else if (item.kind == _SettingKind.drmMode) {
        _cycleDrm(-1);
      } else if (widget.onMoveToNav != null) {
        _moveToNav();
      } else if (widget.showBackButton) {
        setState(() => _zone = TvZone.nav);
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (item.kind == _SettingKind.tvGrid) {
        _adjustTvGrid(1);
      } else if (item.kind == _SettingKind.drmMode) {
        _cycleDrm(1);
      } else {
        _activate(item.kind);
      }
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      _activate(item.kind);
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sectionWidgets = <Widget>[];
    var cursor = 0;
    for (final section in _sections) {
      final rows = <Widget>[];
      for (final item in section.items) {
        final rowIndex = cursor++;
        rows.add(_DeterministicSettingRow(
          item: item,
          focused: _zone == TvZone.settings && _cursor == rowIndex,
          height: _rowHeight(item),
          onTap: () {
            setState(() {
              _zone = TvZone.settings;
              _cursor = rowIndex;
            });
            _activate(item.kind);
          },
        ));
      }
      sectionWidgets.addAll([
        SizedBox(height: _sectionTitleHeight, child: _SectionTitle(section.title)),
        const SizedBox(height: 10),
        _SettingsCard(description: section.description, children: rows),
        const SizedBox(height: _sectionGap),
      ]);
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: Focus(
        focusNode: _rootNode,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor: AppTheme.bgDeep,
          body: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(_horizontalPadding, _topPadding, _horizontalPadding, _bottomPadding),
              cacheExtent: 420,
              children: [
                _Header(
                  height: _headerHeight,
                  showBackButton: widget.showBackButton,
                  focused: _zone == TvZone.nav,
                  onTap: _handleBack,
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  height: _pillsHeight,
                  child: Row(
                    children: [
                      _HeaderPill('Display'),
                      SizedBox(width: 10),
                      _HeaderPill('Source'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...sectionWidgets,
                SizedBox(
                  height: _footerHeight,
                  child: Text(
                    _zone == TvZone.settings
                        ? 'Remote: ↑↓ pilih item • OK/→ ubah nilai • ←/Back kembali'
                        : 'Remote: ↓/→ masuk pengaturan • ←/Back kembali',
                    style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
