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
  int _index = 0;
  int _homeTicket = 0;
  int _accountTicket = 0;
  int _placeholderTicket = 0;

  late final List<FocusNode> _navNodes;

  @override
  void initState() {
    super.initState();
    _navNodes = List.generate(
      TvSideNav.items.length,
      (i) => FocusNode(skipTraversal: true, debugLabel: 'tv-nav-$i'),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _navNodes.isNotEmpty) _navNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _navNodes) {
      node.dispose();
    }
    super.dispose();
  }

  int _safeNav(int value) {
    if (_navNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = _navNodes.length - 1;
    if (value > max) return max;
    return value;
  }

  bool get _navHasFocus => _navNodes.any((node) => node.hasFocus);

  void _focusCurrentNav() {
    if (_navNodes.isEmpty) return;
    _navNodes[_safeNav(_index)].requestFocus();
  }

  void _openNavPage(int navIndex) {
    final safe = _safeNav(navIndex);
    setState(() => _index = safe);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navNodes[safe].requestFocus();
    });
  }

  void _enterContent(int navIndex) {
    final safe = _safeNav(navIndex);
    if (safe != _index) {
      setState(() => _index = safe);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bumpContentTicket();
      });
      return;
    }
    _bumpContentTicket();
  }

  void _bumpContentTicket() {
    if (!mounted) return;
    setState(() {
      if (_index == 0) {
        _homeTicket++;
      } else if (_index == 5) {
        _accountTicket++;
      } else {
        _placeholderTicket++;
      }
    });
  }

  Widget _page() {
    switch (_index) {
      case 0:
        return TvHomeScreen(
          focusTicket: _homeTicket,
          onMoveToNav: _focusCurrentNav,
        );
      case 1:
        return TvPlaceholderScreen(
          title: 'Histori',
          icon: Icons.history_rounded,
          focusTicket: _placeholderTicket,
          onMoveToNav: _focusCurrentNav,
        );
      case 2:
        return TvPlaceholderScreen(
          title: 'Cari',
          icon: Icons.search_rounded,
          focusTicket: _placeholderTicket,
          onMoveToNav: _focusCurrentNav,
        );
      case 3:
        return TvPlaceholderScreen(
          title: 'Favorit',
          icon: Icons.favorite_rounded,
          focusTicket: _placeholderTicket,
          onMoveToNav: _focusCurrentNav,
        );
      case 4:
        return TvPlaceholderScreen(
          title: 'Unduhan',
          icon: Icons.download_rounded,
          focusTicket: _placeholderTicket,
          onMoveToNav: _focusCurrentNav,
        );
      case 5:
        return TvAccountScreen(
          focusTicket: _accountTicket,
          onMoveToNav: _focusCurrentNav,
        );
      default:
        return TvHomeScreen(
          focusTicket: _homeTicket,
          onMoveToNav: _focusCurrentNav,
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
    if (!_navHasFocus) {
      _focusCurrentNav();
      return;
    }
    if (_index != 0) {
      _openNavPage(0);
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
                      index: _index,
                      focusNodes: _navNodes,
                      onChanged: _openNavPage,
                      onOpenContent: _enterContent,
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: KeyedSubtree(key: ValueKey(_index), child: _page()),
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
