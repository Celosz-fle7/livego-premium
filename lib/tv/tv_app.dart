import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';
import '../shared/widgets/premium_shell.dart';
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

  Widget _page() {
    return switch (index) {
      0 => const TvHomeScreen(),
      1 => const TvPlaceholderScreen(title: 'Unduhan', icon: Icons.download_rounded, subtitle: 'Download manager TV akan dipasang setelah player stabil.'),
      2 => const TvPlaceholderScreen(title: 'Riwayat', icon: Icons.history_rounded, subtitle: 'Lanjutkan tontonan terakhir dari layar TV.'),
      3 => const TvPlaceholderScreen(title: 'Favorit', icon: Icons.favorite_rounded, subtitle: 'Daftar judul favorit kamu akan tampil di sini.'),
      4 => const TvAccountScreen(),
      _ => const TvSettingsScreen(),
    };
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(.62),
      builder: (_) => const _TvExitDialog(),
    );
    if (exit == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) { _confirmExit(); return null; }),
        },
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (!didPop) await _confirmExit();
          },
          child: Scaffold(
            body: PremiumShell(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Stack(
                  children: [
                    Positioned.fill(child: _page()),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TvSideNav(
                        index: index,
                        onChanged: (v) => setState(() => index = v),
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

class _TvExitDialog extends StatelessWidget {
  const _TvExitDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF111B2B).withOpacity(.98),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF2A3D59)),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 38)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(color: const Color(0xFF102337), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.cyan.withOpacity(.45))),
              child: const Text('Konfirmasi', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 22),
            const Text('Sudah selesai nontonnya?', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Yakin mau keluar dari LiveGO sekarang?', style: TextStyle(color: AppTheme.textSoft, fontSize: 18)),
            const SizedBox(height: 26),
            const Divider(color: Colors.white12),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _DialogButton(label: 'Nanti Dulu', onTap: () => Navigator.pop(context, false))),
                const SizedBox(width: 16),
                Expanded(child: _DialogButton(label: 'Ya, Keluar', primary: true, onTap: () => Navigator.pop(context, true))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _DialogButton({required this.label, required this.onTap, this.primary = false});

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.primary,
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.primary ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
            color: widget.primary ? null : const Color(0xFF172235),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: focused ? AppTheme.cyan : Colors.white12, width: focused ? 2.4 : 1),
          ),
          child: Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
