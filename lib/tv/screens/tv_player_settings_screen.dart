import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../services/player/player_preferences.dart';
import '../focus/tv_focus_utils.dart';
import '../widgets/tv_focused_border.dart';

class TvPlayerSettingsScreen extends StatefulWidget {
  const TvPlayerSettingsScreen({super.key});

  @override
  State<TvPlayerSettingsScreen> createState() => _TvPlayerSettingsScreenState();
}

class _TvPlayerSettingsScreenState extends State<TvPlayerSettingsScreen> {
  final List<FocusNode> _nodes = [];
  final ScrollController _scrollController = ScrollController();
  int _last = 0;
  double _speed = 1.0;
  String _audio = 'Source';

  List<_PlayerSettingItem> get _items => [
        _PlayerSettingItem(
          icon: Icons.cached_rounded,
          title: 'Cache Playback',
          subtitle: 'Simpan potongan stream sementara agar perpindahan episode lebih stabil.',
          value: LiveGoSettings.cachePlayback ? 'ON' : 'OFF',
          kind: _PlayerSettingKind.cache,
        ),
        _PlayerSettingItem(
          icon: Icons.rotate_90_degrees_ccw_rounded,
          title: 'Tombol Rotasi Manual',
          subtitle: 'Tampilkan kontrol rotasi manual untuk mode HP. TV tetap landscape.',
          value: LiveGoSettings.manualRotateButton ? 'ON' : 'OFF',
          kind: _PlayerSettingKind.rotate,
        ),
        _PlayerSettingItem(
          icon: Icons.lock_rounded,
          title: 'Widevine DRM',
          subtitle: 'LEFT/RIGHT untuk memilih mode kompatibilitas playback.',
          value: LiveGoSettings.drmMode,
          kind: _PlayerSettingKind.drm,
        ),
        _PlayerSettingItem(
          icon: Icons.high_quality_rounded,
          title: 'Kualitas Default',
          subtitle: 'Preferensi kualitas awal. Stream nyata tetap mengikuti source yang tersedia.',
          value: LiveGoSettings.quality,
          kind: _PlayerSettingKind.quality,
        ),
        _PlayerSettingItem(
          icon: Icons.speed_rounded,
          title: 'Kecepatan Default',
          subtitle: 'LEFT/RIGHT untuk mengatur kecepatan awal player TV.',
          value: '${_speed.toStringAsFixed(2)}x',
          kind: _PlayerSettingKind.speed,
        ),
        _PlayerSettingItem(
          icon: Icons.skip_next_rounded,
          title: 'Auto Next Episode',
          subtitle: 'Lanjut otomatis ke episode berikutnya saat video selesai.',
          value: LiveGoSettings.autoNextEnabled ? 'ON' : 'OFF',
          kind: _PlayerSettingKind.autoNext,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusRow(0));
  }

  Future<void> _loadPrefs() async {
    await PlayerPreferences.load();
    if (!mounted) return;
    setState(() {
      _speed = PlayerPreferences.speed;
      _audio = PlayerPreferences.audioTrack;
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncNodes(int count) {
    while (_nodes.length < count) {
      _nodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-player-setting-${_nodes.length}'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
  }

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space;

  bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack;

  void _focusRow(int index) {
    if (_nodes.isEmpty) return;
    _last = index.clamp(0, _nodes.length - 1).toInt();
    tvFocus(_nodes[_last], alignment: 0.24);
  }

  String _nextFrom(List<String> values, String current, int delta) {
    final base = values.indexOf(current);
    final idx = base < 0 ? 0 : base;
    final next = (idx + delta) % values.length;
    return values[next < 0 ? next + values.length : next];
  }

  void _change(_PlayerSettingKind kind, int delta) {
    setState(() {
      switch (kind) {
        case _PlayerSettingKind.cache:
          if (delta == 0) LiveGoSettings.cachePlayback = !LiveGoSettings.cachePlayback;
          else LiveGoSettings.cachePlayback = delta > 0;
          break;
        case _PlayerSettingKind.rotate:
          if (delta == 0) LiveGoSettings.manualRotateButton = !LiveGoSettings.manualRotateButton;
          else LiveGoSettings.manualRotateButton = delta > 0;
          break;
        case _PlayerSettingKind.drm:
          LiveGoSettings.drmMode = _nextFrom(const ['Auto', 'Paksa L3', 'Nonaktifkan Paksa L3'], LiveGoSettings.drmMode, delta == 0 ? 1 : delta);
          break;
        case _PlayerSettingKind.quality:
          LiveGoSettings.quality = _nextFrom(const ['Auto', '480P', '720P', '1080P'], LiveGoSettings.quality, delta == 0 ? 1 : delta);
          break;
        case _PlayerSettingKind.speed:
          final next = (_speed + (delta == 0 ? 0.25 : 0.25 * delta)).clamp(0.5, 2.0).toDouble();
          _speed = next;
          PlayerPreferences.setSpeed(next);
          break;
        case _PlayerSettingKind.autoNext:
          if (delta == 0) LiveGoSettings.autoNextEnabled = !LiveGoSettings.autoNextEnabled;
          else LiveGoSettings.autoNextEnabled = delta > 0;
          break;
      }
    });
  }

  KeyEventResult _rowKey(int index, _PlayerSettingItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusRow(index == 0 ? 0 : index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusRow(index < _nodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _change(item.kind, -1);
      _focusRow(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _change(item.kind, 1);
      _focusRow(index);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _change(item.kind, 0);
      _focusRow(index);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      Navigator.of(context).maybePop();
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
        SingleActivator(LogicalKeyboardKey.goBack): _TvPlayerSettingsBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _TvPlayerSettingsBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _TvPlayerSettingsBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TvPlayerSettingsBackIntent: CallbackAction<_TvPlayerSettingsBackIntent>(onInvoke: (_) {
            Navigator.of(context).maybePop();
            return null;
          }),
        },
        child: Scaffold(
          backgroundColor: AppTheme.bgDeep,
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 18, 36, 28),
            children: [
              _PlayerSettingsHeader(audio: _audio),
              const SizedBox(height: 16),
              const Text('PLAYER TV', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, decoration: TextDecoration.none)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _PlayerSettingRow(
                        node: _nodes[i],
                        item: items[i],
                        onKey: (node, event) => _rowKey(i, items[i], event),
                        isLast: i == items.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Remote: ↑↓ pilih • ←/→ ubah nilai • OK toggle/next • Back kembali', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvPlayerSettingsBackIntent extends Intent {
  const _TvPlayerSettingsBackIntent();
}

enum _PlayerSettingKind { cache, rotate, drm, quality, speed, autoNext }

class _PlayerSettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final _PlayerSettingKind kind;
  const _PlayerSettingItem({required this.icon, required this.title, required this.subtitle, required this.value, required this.kind});
}

class _PlayerSettingsHeader extends StatelessWidget {
  final String audio;
  const _PlayerSettingsHeader({required this.audio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          InkWell(
            canRequestFocus: false,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pengaturan Player', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 4),
                Text('Playback, cache, DRM, kualitas, speed, dan auto next. Audio terakhir: $audio', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSettingRow extends StatelessWidget {
  final FocusNode node;
  final _PlayerSettingItem item;
  final FocusOnKeyEventCallback onKey;
  final bool isLast;

  const _PlayerSettingRow({required this.node, required this.item, required this.onKey, required this.isLast});

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
          child: Column(
            children: [
              TvFocusedBorder(
                focusNode: node,
                color: AppTheme.cyan,
                radius: 18,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: focused ? AppTheme.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                        child: Icon(item.icon, color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                            const SizedBox(height: 4),
                            Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(item.value, style: const TextStyle(color: AppTheme.cyan, fontSize: 13, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      const SizedBox(width: 10),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 24),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(color: AppTheme.border, height: 1),
            ],
          ),
        );
      },
    );
  }
}
