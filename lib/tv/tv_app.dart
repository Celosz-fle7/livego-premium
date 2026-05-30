import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/widgets/premium_shell.dart';
import 'screens/tv_account_screen.dart';
import 'screens/tv_home_screen.dart';
import 'screens/tv_placeholder_screen.dart';
import 'widgets/tv_side_nav.dart';

class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  int index = 0;
  int _homeFocusTicket = 0;
  final FocusNode _contentGuard = FocusNode(debugLabel: 'tv-content-guard');
  late final List<FocusNode> _navNodes;

  @override
  void initState() {
    super.initState();
    _navNodes = List.generate(TvSideNav.items.length, (i) => FocusNode(debugLabel: 'tv-nav-$i'));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _navNodes.first.requestFocus());
  }

  @override
  void dispose() {
    for (final node in _navNodes) {
      node.dispose();
    }
    _contentGuard.dispose();
    super.dispose();
  }

  void _focusCurrentNav() {
    final target = index.clamp(0, _navNodes.length - 1);
    _navNodes[target].requestFocus();
  }

  void _focusRightZone() {
    if (index == 0) {
      setState(() => _homeFocusTicket++);
    } else {
      _contentGuard.requestFocus();
    }
  }

  Widget _page() {
    return switch (index) {
      0 => TvHomeScreen(onMoveToNav: _focusCurrentNav, focusTicket: _homeFocusTicket),
      1 => const TvPlaceholderScreen(title: 'Unduhan', icon: Icons.download_rounded),
      2 => const TvPlaceholderScreen(title: 'Riwayat', icon: Icons.history_rounded),
      3 => const TvPlaceholderScreen(title: 'Favorit', icon: Icons.favorite_rounded),
      4 => const TvAccountScreen(),
      _ => const TvPlaceholderScreen(title: 'Cari', icon: Icons.search_rounded),
    };
  }

  void _selectPage(int value, {bool moveToContent = false}) {
    setState(() {
      index = value;
      if (moveToContent && value == 0) _homeFocusTicket++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (moveToContent) {
        _focusRightZone();
      } else {
        _navNodes[value.clamp(0, _navNodes.length - 1)].requestFocus();
      }
    });
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B1220),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF1E3850)),
        ),
        title: const Text('Keluar dari LiveGO?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, decoration: TextDecoration.none)),
        content: const Text('Tutup aplikasi di Android TV?', style: TextStyle(color: Colors.white70, fontSize: 15, decoration: TextDecoration.none)),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _handleBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    if (index != 0) {
      _selectPage(0);
      return;
    }
    if (await _confirmExit()) SystemNavigator.pop();
  }

  KeyEventResult _contentKey(FocusNode node, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _navNodes[index.clamp(0, _navNodes.length - 1)].requestFocus();
      return KeyEventResult.handled;
    }
    if (node.hasFocus && (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select)) {
      _focusRightZone();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.browserBack) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (!didPop) await _handleBack();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF050914),
          body: PremiumShell(
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.goBack): _TvBackIntent(),
                SingleActivator(LogicalKeyboardKey.escape): _TvBackIntent(),
                SingleActivator(LogicalKeyboardKey.browserBack): _TvBackIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _TvBackIntent: CallbackAction<_TvBackIntent>(onInvoke: (_) {
                    _handleBack();
                    return null;
                  }),
                },
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Row(
                    children: [
                      TvSideNav(
                        index: index,
                        focusNodes: _navNodes,
                        onChanged: (v) => _selectPage(v),
                        onOpenContent: (v) => _selectPage(v, moveToContent: true),
                      ),
                      Expanded(
                        child: Focus(
                          focusNode: _contentGuard,
                          onKey: _contentKey,
                          child: RepaintBoundary(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: KeyedSubtree(key: ValueKey(index), child: _page()),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvBackIntent extends Intent {
  const _TvBackIntent();
}
