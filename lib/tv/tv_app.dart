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
  final FocusNode _shellFocus = FocusNode(debugLabel: 'tv-shell');

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _shellFocus.requestFocus());
  }

  @override
  void dispose() {
    _shellFocus.dispose();
    super.dispose();
  }

  Widget _page() {
    return switch (index) {
      0 => const TvHomeScreen(),
      1 => const TvPlaceholderScreen(title: 'Unduhan', icon: Icons.download_rounded),
      2 => const TvPlaceholderScreen(title: 'Riwayat', icon: Icons.history_rounded),
      3 => const TvPlaceholderScreen(title: 'Favorit', icon: Icons.favorite_rounded),
      4 => const TvAccountScreen(),
      _ => const TvPlaceholderScreen(title: 'Cari', icon: Icons.search_rounded),
    };
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B1220),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF1E3850)),
        ),
        title: const Text('Keluar dari LiveGO?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, decoration: TextDecoration.none)),
        content: const Text('Tutup aplikasi di Android TV?', style: TextStyle(color: Colors.white70, fontSize: 16, decoration: TextDecoration.none)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
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
      setState(() => index = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _shellFocus.requestFocus());
      return;
    }
    if (await _confirmExit()) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
              child: Focus(
                focusNode: _shellFocus,
                autofocus: true,
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Row(
                    children: [
                      TvSideNav(index: index, onChanged: (v) => setState(() => index = v)),
                      Expanded(child: RepaintBoundary(child: _page())),
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
