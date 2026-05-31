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

enum _SettingsFocusZone { tab, row, back }

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  static const tabs = ['Tampilan', 'Player', 'Sumber'];

  final List<FocusNode> _tabNodes = List.generate(
    tabs.length,
    (i) => FocusNode(skipTraversal: true, debugLabel: 'tv-settings-tab-$i'),
  );
  final List<FocusNode> _rowNodes = [];
  late final FocusNode _backNode;

  int _tab = 0;
  int _row = 0;
  _SettingsFocusZone _zone = _SettingsFocusZone.row;

  @override
  void initState() {
    super.initState();
    _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-settings-back');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRowNodes(_entries.length);
      _focusRow(0);
    });
  }

  @override
  void didUpdateWidget(covariant TvSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusTicket != widget.focusTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restoreRightFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final node in _tabNodes) {
      node.dispose();
    }
    for (final node in _rowNodes) {
      node.dispose();
    }
    _backNode.dispose();
    super.dispose();
  }

  void _syncRowNodes(int count) {
    while (_rowNodes.length < count) {
      _rowNodes.add(FocusNode(
        skipTraversal: true,
        debugLabel: 'tv-settings-row-${_rowNodes.length}',
      ));
    }
    while (_rowNodes.length > count) {
      _rowNodes.removeLast().dispose();
    }
    if (_rowNodes.isNotEmpty) _row = _row.clamp(0, _rowNodes.length - 1);
  }

  List<_SettingEntry> get _entries {
    if (_tab == 0) {
      return [
        _SettingEntry(
          icon: Icons.auto_awesome_motion_rounded,
          title: 'Mode Tampilan',
          subtitle: 'Untuk Android TV gunakan Auto atau TV.',
          value: LiveGoSettings.layoutMode,
          onTap: _cycleLayout,
        ),
        _SettingEntry(
          icon: Icons.grid_view_rounded,
          title: 'Grid Home TV',
          subtitle: 'Jumlah kolom poster di layar Home TV.',
          value: '${LiveGoSettings.tvHomeGrid} kolom',
          onTap: _cycleGrid,
        ),
        _SettingEntry(
          icon: Icons.speed_rounded,
          title: 'Mode TV Ringan',
          subtitle: 'Kurangi efek agar remote dan scroll lebih responsif.',
          value: LiveGoSettings.lowEndTvMode ? 'ON' : 'OFF',
          onTap: () => setState(() => LiveGoSettings.lowEndTvMode = !LiveGoSettings.lowEndTvMode),
        ),
        _SettingEntry(
          icon: Icons.image_rounded,
          title: 'Background Poster',
          subtitle: 'Poster ambience di detail/player.',
          value: LiveGoSettings.backgroundPoster ? 'ON' : 'OFF',
          onTap: () => setState(() => LiveGoSettings.backgroundPoster = !LiveGoSettings.backgroundPoster),
        ),
      ];
    }

    if (_tab == 1) {
      return [
        _SettingEntry(
          icon: Icons.high_quality_rounded,
          title: 'Kualitas Default',
          subtitle: 'Pilihan awal stream saat player dibuka.',
          value: LiveGoSettings.quality,
          onTap: _cycleQuality,
        ),
        _SettingEntry(
          icon: Icons.subtitles_rounded,
          title: 'Subtitle',
          subtitle: 'Aktifkan subtitle bawaan jika tersedia.',
          value: LiveGoSettings.subtitlesEnabled ? 'ON' : 'OFF',
          onTap: () => setState(() => LiveGoSettings.subtitlesEnabled = !LiveGoSettings.subtitlesEnabled),
        ),
        _SettingEntry(
          icon: Icons.skip_next_rounded,
          title: 'Auto Next Episode',
          subtitle: 'Lanjut otomatis ke episode berikutnya.',
          value: LiveGoSettings.autoNextEnabled ? 'ON' : 'OFF',
          onTap: () => setState(() => LiveGoSettings.autoNextEnabled = !LiveGoSettings.autoNextEnabled),
        ),
        _SettingEntry(
          icon: Icons.cached_rounded,
          title: 'Cache Playback',
          subtitle: 'Cache sementara agar playback lebih stabil.',
          value: LiveGoSettings.cachePlayback ? 'ON' : 'OFF',
          onTap: () => setState(() => LiveGoSettings.cachePlayback = !LiveGoSettings.cachePlayback),
        ),
        _SettingEntry(
          icon: Icons.screen_rotation_alt_rounded,
          title: 'Tombol Rotasi Manual',
          subtitle: 'Tampilkan tombol rotasi saat menonton.',
          value: LiveGoSettings.manualRotateButton ? 'ON' : 'OFF',
          onTap: () => setState(() => LiveGoSettings.manualRotateButton = !LiveGoSettings.manualRotateButton),
        ),
        _SettingEntry(
          icon: Icons.lock_rounded,
          title: 'Widevine DRM',
          subtitle: 'Mode kompatibilitas DRM perangkat tertentu.',
          value: LiveGoSettings.drmMode,
          onTap: _cycleDrm,
        ),
      ];
    }

    return [
      _SettingEntry(
        icon: Icons.layers_rounded,
        title: 'Default Platform',
        subtitle: 'Platform utama untuk data awal.',
        value: LiveGoSettings.defaultPlatform,
        onTap: _cyclePlatform,
      ),
      _SettingEntry(
        icon: Icons.language_rounded,
        title: 'Bahasa',
        subtitle: 'Bahasa UI dan metadata jika tersedia.',
        value: LiveGoSettings.language.toUpperCase(),
        onTap: _cycleLanguage,
      ),
      _SettingEntry(
        icon: Icons.apps_rounded,
        title: 'Platform Aktif',
        subtitle: 'Jumlah provider yang aktif saat ini.',
        value: '${LiveGoSettings.activePlatforms.length} aktif',
        onTap: _cyclePlatform,
      ),
      _SettingEntry(
        icon: Icons.home_repair_service_rounded,
        title: 'Platform Home',
        subtitle: 'Provider yang tampil di Home.',
        value: '${LiveGoSettings.homePlatforms.length} home',
        onTap: _cyclePlatform,
      ),
      _SettingEntry(
        icon: Icons.delete_rounded,
        title: 'Reset Pengaturan',
        subtitle: 'Kembalikan semua pengaturan ke bawaan.',
        value: 'RESET',
        danger: true,
        changeWithRight: false,
        onTap: () => setState(LiveGoSettings.reset),
      ),
    ];
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

  void _moveToNav() {
    widget.onMoveToNav?.call();
  }

  void _focusBack() {
    if (!widget.showBackButton) return;
    _zone = _SettingsFocusZone.back;
    focusAndReveal(_backNode, alignment: 0.04);
  }

  void _focusTab(int index) {
    final safe = index.clamp(0, _tabNodes.length - 1);
    _tab = safe;
    _zone = _SettingsFocusZone.tab;
    focusAndReveal(_tabNodes[safe], alignment: 0.06);
  }

  void _focusRow(int index) {
    if (_rowNodes.isEmpty) return;
    final safe = index.clamp(0, _rowNodes.length - 1);
    _row = safe;
    _zone = _SettingsFocusZone.row;
    focusAndReveal(_rowNodes[safe], alignment: 0.22);
  }

  void _restoreRightFocus() {
    _syncRowNodes(_entries.length);
    if (_zone == _SettingsFocusZone.tab) {
      _focusTab(_tab);
      return;
    }
    if (_zone == _SettingsFocusZone.back && widget.showBackButton) {
      _focusBack();
      return;
    }
    _focusRow(_row);
  }

  void _selectTab(int index, {bool moveToRows = false}) {
    final safe = index.clamp(0, tabs.length - 1);
    setState(() {
      _tab = safe;
      _row = 0;
      _syncRowNodes(_entries.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (moveToRows) {
        _focusRow(0);
      } else {
        _focusTab(safe);
      }
    });
  }

  KeyEventResult _backKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      _focusTab(_tab);
      return KeyEventResult.handled;
    }

    if (_isSelect(key) || _isBack(key)) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _tabKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        if (widget.showBackButton) {
          _focusBack();
        } else {
          _moveToNav();
        }
      } else {
        _selectTab(index - 1);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < tabs.length - 1) {
        _selectTab(index + 1);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _focusRow(0);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.showBackButton) _focusBack();
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      _selectTab(index, moveToRows: true);
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

  KeyEventResult _rowKey(int index, _SettingEntry entry, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) {
        _focusTab(_tab);
      } else {
        _focusRow(index - 1);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (index < _rowNodes.length - 1) {
        _focusRow(index + 1);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNav();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (entry.changeWithRight) entry.onTap();
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      entry.onTap();
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

  void _cycleLayout() {
    const values = ['Auto', 'Mobile', 'TV'];
    final idx = values.indexOf(LiveGoSettings.layoutMode);
    setState(() => LiveGoSettings.layoutMode = values[(idx + 1) % values.length]);
  }

  void _cycleGrid() {
    setState(() {
      LiveGoSettings.setTvHomeGrid(LiveGoSettings.tvHomeGrid >= 10 ? 4 : LiveGoSettings.tvHomeGrid + 1);
    });
  }

  void _cycleQuality() {
    const values = ['Auto', '480p', '720p', '1080p'];
    final idx = values.indexOf(LiveGoSettings.quality);
    setState(() => LiveGoSettings.quality = values[(idx + 1) % values.length]);
  }

  void _cycleDrm() {
    const values = ['Auto', 'Paksa L3', 'Matikan'];
    final idx = values.indexOf(LiveGoSettings.drmMode);
    setState(() => LiveGoSettings.drmMode = values[(idx + 1) % values.length]);
  }

  void _cyclePlatform() {
    final values = LiveGoSettings.defaultPlatforms;
    if (values.isEmpty) return;
    final idx = values.indexOf(LiveGoSettings.defaultPlatform);
    setState(() => LiveGoSettings.defaultPlatform = values[(idx + 1) % values.length]);
  }

  void _cycleLanguage() {
    const values = ['id', 'en', 'th', 'ar'];
    final idx = values.indexOf(LiveGoSettings.language);
    setState(() => LiveGoSettings.language = values[(idx + 1) % values.length]);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    _syncRowNodes(entries.length);

    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 30, 30),
          children: [
            _Header(
              showBackButton: widget.showBackButton,
              backNode: _backNode,
              onBackKey: _backKey,
            ),
            const SizedBox(height: 14),
            _TabZone(
              tab: _tab,
              nodes: _tabNodes,
              labels: tabs,
              onKey: _tabKey,
              onTap: (i) => _selectTab(i),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const _SectionTitle('Bagian Kanan'),
                const Spacer(),
                Text(
                  '↑↓ pilih • OK/→ ubah • ← kembali navbar',
                  style: TextStyle(
                    color: AppTheme.textSoft.withOpacity(0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Panel(
              children: List.generate(entries.length, (i) {
                return _SettingRow(
                  node: _rowNodes[i],
                  entry: entries[i],
                  onKey: (node, event) => _rowKey(i, entries[i], event),
                  onTap: entries[i].onTap,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;
  final bool danger;
  final bool changeWithRight;

  const _SettingEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.danger = false,
    this.changeWithRight = true,
  });
}

class _Header extends StatelessWidget {
  final bool showBackButton;
  final FocusNode backNode;
  final FocusOnKeyEventCallback onBackKey;

  const _Header({
    required this.showBackButton,
    required this.backNode,
    required this.onBackKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0B2634), Color(0xFF080D17)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E3850)),
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            _BackButton(node: backNode, onKey: onBackKey),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pengaturan LiveGO TV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Navigasi kanan dibuat manual untuk remote Android TV.',
                  style: TextStyle(
                    color: AppTheme.textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF08111F),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.24)),
            ),
            child: const Text(
              'REMOTE MODE',
              style: TextStyle(
                color: AppTheme.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                decoration: TextDecoration.none,
              ),
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
          width: 52,
          height: 52,
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

class _TabZone extends StatelessWidget {
  final int tab;
  final List<FocusNode> nodes;
  final List<String> labels;
  final KeyEventResult Function(int index, KeyEvent event) onKey;
  final ValueChanged<int> onTap;

  const _TabZone({
    required this.tab,
    required this.nodes,
    required this.labels,
    required this.onKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF08111E).withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1A2D43)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
              child: _TabChip(
                node: nodes[i],
                text: labels[i],
                active: i == tab,
                onTap: () => onTap(i),
                onKey: (node, event) => onKey(i, event),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final FocusNode node;
  final String text;
  final bool active;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

  const _TabChip({
    required this.node,
    required this.text,
    required this.active,
    required this.onTap,
    required this.onKey,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = _focused || widget.active;
    return Focus(
      focusNode: widget.node,
      skipTraversal: true,
      onKeyEvent: widget.onKey,
      onFocusChange: (v) => setState(() => _focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF123B54), Color(0xFF3C207E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: selected ? null : const Color(0xFF0A1422),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.62) : Colors.white10),
              width: _focused ? 2.2 : 1,
            ),
            boxShadow: _focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 16)] : null,
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSoft,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
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

class _SettingRow extends StatefulWidget {
  final FocusNode node;
  final _SettingEntry entry;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _SettingRow({
    required this.node,
    required this.entry,
    required this.onKey,
    required this.onTap,
  });

  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.entry.danger ? const Color(0xFFFF6B7A) : AppTheme.cyan;
    return Focus(
      focusNode: widget.node,
      skipTraversal: true,
      onKeyEvent: widget.onKey,
      onFocusChange: (v) => setState(() => _focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          minHeight: 76,
          margin: const EdgeInsets.all(7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF102F45) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _focused ? color : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF102033),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: Icon(widget.entry.icon, color: widget.entry.danger ? color : Colors.white, size: 25),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.entry.title,
                      style: TextStyle(
                        color: widget.entry.danger ? color : Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                constraints: const BoxConstraints(minWidth: 92),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _focused ? color.withOpacity(0.14) : const Color(0xFF07101C),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _focused ? color.withOpacity(0.8) : Colors.white10),
                ),
                child: Text(
                  widget.entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _focused ? color : AppTheme.textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                widget.entry.danger ? Icons.check_rounded : Icons.keyboard_arrow_right_rounded,
                color: _focused ? color : Colors.white30,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        decoration: TextDecoration.none,
      ),
    );
  }
}
