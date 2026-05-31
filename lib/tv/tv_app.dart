import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/widgets/premium_shell.dart';
import 'focus/tv_focus_memory.dart';
import 'screens/tv_account_screen.dart';
import 'screens/tv_home_screen.dart';
import 'screens/tv_placeholder_screen.dart';
import 'screens/tv_settings_screen.dart';
import 'widgets/tv_side_nav.dart';

class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  int index = 0;

  int _homeFocusTicket = 0;
  int _placeholderFocusTicket = 0;
  int _accountFocusTicket = 0;
  int _settingsFocusTicket = 0;

  late final List<FocusNode> _navNodes;
  final TvFocusMemory _homeMemory = TvFocusMemory();
  final TvFocusMemory _accountMemory = TvFocusMemory();
  final TvFocusMemory _settingsMemory = TvFocusMemory();

  @override
  void initState() {
    super.initState();
    _navNodes = List.generate(
      TvSideNav.items.length,
      (i) => FocusNode(skipTraversal: true, debugLabel: 'tv-nav-$i'),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _navNodes) {
      node.dispose();
    }
    super.dispose();
  }

  int _safeNavIndex(int value) {
    final max = _navNodes.length - 1;
    if (value < 0) return 0;
    if (value > max) return max;
    return value;
  }

  void _focusCurrentNav() {
    final target = _safeNavIndex(index);
    _navNodes[target].requestFocus();
  }

  void _focusRightZone() {
    if (!mounted) return;
    setState(() {
      switch (index) {
        case 0:
          _homeFocusTicket++;
          break;
        case 5:
          _accountFocusTicket++;
          break;
        case 6:
          _settingsFocusTicket++;
          break;
        default:
          _placeholderFocusTicket++;
          break;
      }
    });
  }

  void _moveFromNavToContent(int navIndex) {
    final safe = _safeNavIndex(navIndex);
    if (safe != index) {
      setState(() => index = safe);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusRightZone();
      });
      return;
    }
    _focusRightZone();
  }

  void _selectPage(int value, {bool moveToContent = false}) {
    final safe = _safeNavIndex(value);
    setState(() => index = safe);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (moveToContent) {
        _focusRightZone();
      } else {
        _navNodes[safe].requestFocus();
      }
    });
  }

  Widget _page() {
    switch (index) {
      case 0:
        return TvHomeScreen(
          memory: _homeMemory,
          onMoveToNav: _focusCurrentNav,
          focusTicket: _homeFocusTicket,
        );
      case 1:
        return TvPlaceholderScreen(
          title: 'Histori',
          icon: Icons.history_rounded,
          onMoveToNav: _focusCurrentNav,
          focusTicket: _placeholderFocusTicket,
        );
      case 2:
        return TvPlaceholderScreen(
          title: 'Cari',
          icon: Icons.search_rounded,
          onMoveToNav: _focusCurrentNav,
          focusTicket: _placeholderFocusTicket,
        );
      case 3:
        return TvPlaceholderScreen(
          title: 'Favorit',
          icon: Icons.favorite_rounded,
          onMoveToNav: _focusCurrentNav,
          focusTicket: _placeholderFocusTicket,
        );
      case 4:
        return TvPlaceholderScreen(
          title: 'Unduhan',
          icon: Icons.download_rounded,
          onMoveToNav: _focusCurrentNav,
          focusTicket: _placeholderFocusTicket,
        );
      case 5:
        return TvAccountScreen(
          memory: _accountMemory,
          onMoveToNav: _focusCurrentNav,
          focusTicket: _accountFocusTicket,
        );
      default:
        return TvSettingsScreen(
          memory: _settingsMemory,
          showBackButton: false,
          onMoveToNav: _focusCurrentNav,
          focusTicket: _settingsFocusTicket,
        );
    }
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
        title: const Text(
          'Keluar dari LiveGO?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, decoration: TextDecoration.none),
        ),
        content: const Text(
          'Tutup aplikasi di Android TV?',
          style: TextStyle(color: Colors.white70, fontSize: 15, decoration: TextDecoration.none),
        ),
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
                child: Row(
                  children: [
                    TvSideNav(
                      index: index,
                      focusNodes: _navNodes,
                      onChanged: (v) => _selectPage(v, moveToContent: true),
                      onOpenContent: _moveFromNavToContent,
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: KeyedSubtree(key: ValueKey(index), child: _page()),
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
    );
  }
}

class _TvBackIntent extends Intent {
  const _TvBackIntent();
}
