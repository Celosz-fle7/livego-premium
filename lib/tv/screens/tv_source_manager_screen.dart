import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../utils/tv_focus_utils.dart';
import '../widgets/tv_focused_border.dart';

class TvSourceManagerScreen extends StatefulWidget {
  const TvSourceManagerScreen({super.key});

  @override
  State<TvSourceManagerScreen> createState() => _TvSourceManagerScreenState();
}

class _TvSourceManagerScreenState extends State<TvSourceManagerScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _sourceNodes = [];
  late final FocusNode _backNode;
  late final FocusNode _pingNode;

  int _lastIndex = 0;
  bool _pinging = false;

  List<String> get _platforms => LiveGoCatalog.allPlatforms;

  @override
  void initState() {
    super.initState();
    _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-back');
    _pingNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-ping');
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSource(_lastIndex));
  }

  @override
  void dispose() {
    for (final node in _sourceNodes) {
      node.dispose();
    }
    _backNode.dispose();
    _pingNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncNodes(int count) {
    while (_sourceNodes.length < count) {
      _sourceNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-source-${_sourceNodes.length}'));
    }
    while (_sourceNodes.length > count) {
      _sourceNodes.removeLast().dispose();
    }
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

  int _safe(int index) {
    if (_sourceNodes.isEmpty) return 0;
    return index.clamp(0, _sourceNodes.length - 1).toInt();
  }

  void _focusSource(int index) {
    if (_sourceNodes.isEmpty) return;
    _lastIndex = _safe(index);
    tvFocus(_sourceNodes[_lastIndex], alignment: 0.28);
  }

  void _focusBack() => tvFocus(_backNode, alignment: 0.05);
  void _focusPing() => tvFocus(_pingNode, alignment: 0.05);

  void _goBack() => Navigator.of(context).maybePop();

  Future<void> _pingAll() async {
    if (_pinging) return;
    setState(() => _pinging = true);
    try {
      for (final slug in _platforms) {
        await LiveGoCatalog.pingPlatform(slug);
        if (!mounted) return;
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _pinging = false);
        _focusPing();
      }
    }
  }

  void _toggleActive(String slug, int index) {
    setState(() {
      LiveGoSettings.togglePlatform(slug);
      _lastIndex = index;
    });
    _focusSource(index);
  }

  void _toggleHome(String slug, int index) {
    setState(() {
      LiveGoSettings.toggleHomePlatform(slug);
      _lastIndex = index;
    });
    _focusSource(index);
  }

  KeyEventResult _backKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      _focusSource(_lastIndex);
      return KeyEventResult.handled;
    }
    if (_isSelect(key) || _isBack(key) || key == LogicalKeyboardKey.arrowLeft) {
      _goBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _pingKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
      _focusSource(_lastIndex);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _pingAll();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _goBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _sourceKey(int index, String slug, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) {
        _focusBack();
      } else {
        _focusSource(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _goBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _toggleHome(slug, index);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _toggleActive(slug, index);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _goBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _statusColor(String slug) {
    switch (LiveGoSettings.statusFor(slug)) {
      case 'online':
        return Colors.greenAccent;
      case 'slow':
        return Colors.orangeAccent;
      case 'offline':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  String _sourceDescription(String slug) {
    final map = <String, String>{
      'shortmax': 'Default aman API Anichin.',
      'netshort': 'Source API Anichin aktif.',
      'pinedrama': 'Source API Anichin aktif.',
      'dramabox': 'Source API Anichin aktif.',
      'flickreels': 'Source API Anichin aktif.',
      'melolo': 'Opsional, jangan jadikan default karena DRM/audio masih kompleks.',
    };
    return map[slug] ?? 'Source LiveGo siap dikoneksikan ke API.';
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes(_platforms.length);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.goBack): _TvSourceBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _TvSourceBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _TvSourceBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TvSourceBackIntent: CallbackAction<_TvSourceBackIntent>(onInvoke: (_) {
            _goBack();
            return null;
          }),
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF050914),
          body: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(28, 22, 38, 34),
              children: [
                _Header(
                  backNode: _backNode,
                  pingNode: _pingNode,
                  onBackKey: _backKey,
                  onPingKey: _pingKey,
                  onBack: _goBack,
                  onPing: _pingAll,
                  pinging: _pinging,
                ),
                const SizedBox(height: 18),
                const Text(
                  'SUMBER HOME',
                  style: TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09111E).withOpacity(0.96),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF1C3148)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _platforms.length; i++)
                        _SourceRow(
                          node: _sourceNodes[i],
                          slug: _platforms[i],
                          title: LiveGoCatalog.label(_platforms[i]),
                          subtitle: _sourceDescription(_platforms[i]),
                          active: LiveGoSettings.isPlatformActive(_platforms[i]),
                          home: LiveGoSettings.isHomePlatform(_platforms[i]),
                          statusColor: _statusColor(_platforms[i]),
                          onKey: (node, event) => _sourceKey(i, _platforms[i], event),
                          onTap: () => _toggleActive(_platforms[i], i),
                          onHomeTap: () => _toggleHome(_platforms[i], i),
                          isLast: i == _platforms.length - 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Remote: ↑↓ pilih source • OK aktif/nonaktif • → tampil/sembunyikan di Home • Back kembali',
                  style: TextStyle(color: AppTheme.textSoft.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvSourceBackIntent extends Intent {
  const _TvSourceBackIntent();
}

class _Header extends StatelessWidget {
  final FocusNode backNode;
  final FocusNode pingNode;
  final FocusOnKeyEventCallback onBackKey;
  final FocusOnKeyEventCallback onPingKey;
  final VoidCallback onBack;
  final VoidCallback onPing;
  final bool pinging;

  const _Header({
    required this.backNode,
    required this.pingNode,
    required this.onBackKey,
    required this.onPingKey,
    required this.onBack,
    required this.onPing,
    required this.pinging,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF09111E).withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1C3148)),
      ),
      child: Row(
        children: [
          Focus(
            focusNode: backNode,
            skipTraversal: true,
            onKeyEvent: onBackKey,
            child: InkWell(
              canRequestFocus: false,
              onTap: onBack,
              borderRadius: BorderRadius.circular(16),
              child: TvFocusedBorder(
                focusNode: backNode,
                color: AppTheme.cyan,
                radius: 16,
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Kelola Sumber Data', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Atur platform aktif dan source yang tampil di Home TV.', style: TextStyle(color: AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Focus(
            focusNode: pingNode,
            skipTraversal: true,
            onKeyEvent: onPingKey,
            child: InkWell(
              canRequestFocus: false,
              onTap: pinging ? null : onPing,
              borderRadius: BorderRadius.circular(999),
              child: TvFocusedBorder(
                focusNode: pingNode,
                color: AppTheme.cyan,
                radius: 999,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(pinging ? 'PING...' : 'PING', style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final FocusNode node;
  final String slug;
  final String title;
  final String subtitle;
  final bool active;
  final bool home;
  final Color statusColor;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;
  final VoidCallback onHomeTap;
  final bool isLast;

  const _SourceRow({
    required this.node,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.home,
    required this.statusColor,
    required this.onKey,
    required this.onTap,
    required this.onHomeTap,
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
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: focused ? const Color(0xFF102F45) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2),
                    boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.16), blurRadius: 16)] : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: statusColor.withOpacity(0.35), blurRadius: 10)]),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Pill(text: active ? 'AKTIF' : 'OFF', active: active),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onHomeTap,
                        child: _Pill(text: home ? 'HOME' : 'SEMBUNYI', active: home),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.keyboard_arrow_right_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 26),
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

class _Pill extends StatelessWidget {
  final String text;
  final bool active;

  const _Pill({required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppTheme.cyan.withOpacity(0.16) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppTheme.cyan.withOpacity(0.65) : Colors.white12),
      ),
      child: Text(text, style: TextStyle(color: active ? AppTheme.cyan : Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}
