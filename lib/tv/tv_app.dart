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
  final FocusNode _rootFocus = FocusNode(debugLabel: 'tv-root');

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _rootFocus.requestFocus());
  }

  @override
  void dispose() {
    _rootFocus.dispose();
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
    final exit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0B1220),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: const BorderSide(color: Color(0xFF1F3B55))),
        title: const Text('Sudah selesai nonton?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
        content: const Text('Tutup LiveGO di Android TV?', style: TextStyle(color: Colors.white70, fontSize: 16)),
        actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nanti Dulu')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Keluar')),
        ],
      ),
    );
    return exit == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmExit()) SystemNavigator.pop();
      },
      child: Scaffold(
        body: PremiumShell(
          child: Focus(
            focusNode: _rootFocus,
            autofocus: true,
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.goBack): _BackIntent(),
                SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _BackIntent: CallbackAction<_BackIntent>(onInvoke: (_) async {
                    if (await _confirmExit()) SystemNavigator.pop();
                    return null;
                  }),
                },
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Row(
                    children: [
                      TvSideNav(
                        index: index,
                        onChanged: (v) => setState(() => index = v),
                      ),
                      Expanded(child: _page()),
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

class _BackIntent extends Intent {
  const _BackIntent();
}
