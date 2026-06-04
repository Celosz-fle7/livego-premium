import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../shared/widgets/premium_shell.dart';
import '../focus/tv_focus_utils.dart';
import '../providers/tv_focus_provider.dart';
import '../providers/tv_navigation_provider.dart';
import '../providers/tv_remote_owner.dart';
import '../screens/tv_account_screen.dart';
import '../screens/tv_downloads_screen.dart';
import '../home/tv_home_screen.dart';
import '../screens/tv_library_screen.dart';
import '../screens/tv_search_screen.dart';
import '../theme/tv_focus_style.dart';
import '../widgets/tv_side_nav.dart';
import '../widgets/tv_lazy_indexed_stack.dart';
import 'tv_nav_index.dart';
import 'tv_navigation_service.dart';

class TvShell extends ConsumerStatefulWidget {
  const TvShell({super.key});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  int _index = TvNavIndex.home;
  TvSideNavMode _navMode = TvSideNavMode.hidden;
  int _homeTicket = 0;
  int _homeBannerTicket = 0;
  int _contentTicket = 0;
  int _accountTicket = 0;
  int _backGuardMs = 0;
  int _suppressBackUntilMs = 0;
  bool _exitOpen = false;
  bool _returnToAccount = false;
  final TvNavigationService _navService = TvNavigationService.instance;

  late final FocusNode _rootFocusNode;
  late final List<FocusNode> _navNodes;
  late final FocusNode _exitCancelNode;
  late final FocusNode _exitConfirmNode;
  int _lastBootstrapMs = 0;
  int _bootstrapSerial = 0;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode(skipTraversal: true, debugLabel: 'tv-shell-root');
    _navNodes = List.generate(TvSideNav.items.length, (i) => FocusNode(skipTraversal: true, debugLabel: 'tv-nav-$i'));
    _exitCancelNode = FocusNode(skipTraversal: true, debugLabel: 'tv-exit-cancel');
    _exitConfirmNode = FocusNode(skipTraversal: true, debugLabel: 'tv-exit-confirm');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootFocusNode.requestFocus();
      _syncOwner();
      setState(() => _homeBannerTicket++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bootstrapActiveFocus(forceBanner: true);
      });
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    for (final node in _navNodes) {
      node.dispose();
    }
    _exitCancelNode.dispose();
    _exitConfirmNode.dispose();
    super.dispose();
  }

  int _safeNav(int index) => index.clamp(0, _navNodes.length - 1).toInt();
  bool get _navHasFocus => _navNodes.any((node) => node.hasFocus);

  TvRemoteOwner _ownerFor(int index) {
    switch (index) {
      case TvNavIndex.download:
        return TvRemoteOwner.downloads;
      case TvNavIndex.history:
      case TvNavIndex.favorite:
        return TvRemoteOwner.library;
      case TvNavIndex.account:
        return TvRemoteOwner.account;
      case TvNavIndex.search:
        return TvRemoteOwner.search;
      case TvNavIndex.home:
      default:
        return TvRemoteOwner.home;
    }
  }

  void _syncOwner({bool navFocused = false}) {
    final owner = navFocused ? TvRemoteOwner.navbar : _ownerFor(_index);
    final nav = ref.read(tvNavigationProvider.notifier);
    if (navFocused) {
      nav.selectNav(_index);
    } else {
      nav.enterContent(_index);
    }
    nav.setOwner(owner);
    ref.read(tvFocusProvider.notifier).setOwner(owner);
    _navService.update(
      index: _index,
      navFocused: navFocused,
      owner: owner.name,
      navMode: _navMode.name,
    );
  }

  bool _backAllowed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _suppressBackUntilMs) return false;
    if (now - _backGuardMs < 420) return false;
    _backGuardMs = now;
    return true;
  }

  void _suppressBack([int ms = 650]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _backGuardMs = now;
    final until = now + ms;
    if (until > _suppressBackUntilMs) _suppressBackUntilMs = until;
  }

  void _focusNav(int index) {
    if (_navNodes.isEmpty) return;
    final safe = _safeNav(index);
    final node = _navNodes[safe];
    if (node.context != null) {
      tvFocus(node, alignment: 0.10, throttle: false);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(node, alignment: 0.10, throttle: false);
    });
  }

  void _showNav() {
    setState(() => _navMode = TvSideNavMode.focused);
    _syncOwner(navFocused: true);
    _focusNav(_index);
  }

  void _hideNav() {
    if (_navMode != TvSideNavMode.hidden) setState(() => _navMode = TvSideNavMode.hidden);
    _syncOwner();
  }

  void _enterContent(int navIndex) {
    final safe = _safeNav(navIndex);
    setState(() {
      _index = safe;
      _navMode = TvSideNavMode.hidden;
      _returnToAccount = false;
    });
    _syncOwner();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bumpFocusForCurrent());
  }

  void _openNavIndex(int navIndex) {
    final safe = _safeNav(navIndex);
    setState(() {
      _index = safe;
      _navMode = TvSideNavMode.focused;
      _returnToAccount = false;
    });
    _syncOwner(navFocused: true);
    _focusNav(safe);
  }

  void _openFromAccount(int navIndex) {
    final safe = _safeNav(navIndex);
    if (safe == TvNavIndex.account) return;
    setState(() {
      _index = safe;
      _navMode = TvSideNavMode.hidden;
      _returnToAccount = true;
    });
    _syncOwner();
    _bumpFocusForCurrent();
  }

  void _bumpFocusForCurrent({bool banner = false}) {
    if (!mounted) return;
    setState(() {
      if (_index == TvNavIndex.home) {
        if (banner) {
          _homeBannerTicket++;
        } else {
          _homeTicket++;
        }
      } else if (_index == TvNavIndex.account) {
        _accountTicket++;
      } else {
        _contentTicket++;
      }
    });
  }

  void _returnToAccountMenuOrNav() {
    if (_returnToAccount && _index != TvNavIndex.account) {
      setState(() {
        _returnToAccount = false;
        _index = TvNavIndex.account;
        _navMode = TvSideNavMode.hidden;
        _accountTicket++;
      });
      _syncOwner();
      return;
    }
    _showNav();
  }

  void _preparePlayerRoute() {
    _suppressBack(700);
    _hideNav();
  }

  void _restorePlayerRoute() {
    _suppressBack(650);
    _hideNav();
    _bumpFocusForCurrent();
  }


  bool _isDpadOrActivation(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        tvIsSelectKey(key) ||
        tvIsMenuKey(key);
  }

  bool _primaryFocusMissing() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return true;
    if (primary == _rootFocusNode) return true;
    if (primary.context == null) return true;
    return false;
  }

  void _scheduleBootstrapRetry({bool forceBanner = false, int attempt = 0}) {
    if (!mounted || attempt > 3) return;
    final token = ++_bootstrapSerial;
    final delay = attempt == 0
        ? Duration.zero
        : attempt == 1
            ? const Duration(milliseconds: 50)
            : attempt == 2
                ? const Duration(milliseconds: 150)
                : const Duration(milliseconds: 300);

    Future<void>.delayed(delay, () {
      if (!mounted || token != _bootstrapSerial) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || token != _bootstrapSerial) return;
        _bootstrapActiveFocus(forceBanner: forceBanner, bypassThrottle: true, allowRetry: false);
        if (_primaryFocusMissing() && attempt < 3) {
          _scheduleBootstrapRetry(forceBanner: forceBanner, attempt: attempt + 1);
        }
      });
    });
  }

  void _bootstrapActiveFocus({bool forceBanner = false, bool bypassThrottle = false, bool allowRetry = true}) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!bypassThrottle && now - _lastBootstrapMs < 150) {
      if (allowRetry) _scheduleBootstrapRetry(forceBanner: forceBanner, attempt: 1);
      return;
    }
    _lastBootstrapMs = now;

    if (_exitOpen) {
      tvFocus(_exitCancelNode, alignment: 0.50, throttle: false);
      if (allowRetry) _scheduleBootstrapRetry(forceBanner: forceBanner, attempt: 1);
      return;
    }

    if (_navMode == TvSideNavMode.focused || _navHasFocus) {
      _syncOwner(navFocused: true);
      _focusNav(_index);
      if (allowRetry) _scheduleBootstrapRetry(forceBanner: forceBanner, attempt: 1);
      return;
    }

    _syncOwner();
    _bumpFocusForCurrent(banner: _index == TvNavIndex.home && forceBanner);
    if (allowRetry) _scheduleBootstrapRetry(forceBanner: forceBanner, attempt: 1);
  }

  KeyEventResult _rootKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;

    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }

    if (!_isDpadOrActivation(key)) return KeyEventResult.ignored;

    // If no child has claimed focus, TV remotes send arrows/OK into the void.
    // Keep the root shell focused as a safety net and push focus back into the
    // active screen on the first D-Pad/OK press.
    if (_primaryFocusMissing()) {
      _bootstrapActiveFocus(forceBanner: key != LogicalKeyboardKey.arrowLeft);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showExit() {
    if (_exitOpen) return;
    setState(() => _exitOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_exitCancelNode, alignment: 0.50, throttle: false);
    });
  }

  void _closeExit() {
    if (!_exitOpen) return;
    setState(() => _exitOpen = false);
    if (_index == TvNavIndex.home) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bumpFocusForCurrent(banner: true));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNav());
    }
  }

  void _handleBack() {
    if (!_backAllowed()) return;
    if (_exitOpen) {
      _closeExit();
      return;
    }
    if (_navHasFocus) {
      if (_index == TvNavIndex.home) {
        setState(() => _navMode = TvSideNavMode.hidden);
        _bumpFocusForCurrent(banner: true);
      } else {
        _hideNav();
        _bumpFocusForCurrent();
      }
      return;
    }
    if (_index == TvNavIndex.home) {
      _bumpFocusForCurrent();
    } else {
      _returnToAccountMenuOrNav();
    }
  }

  KeyEventResult _exitKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      tvFocus(node == _exitCancelNode ? _exitConfirmNode : _exitCancelNode, alignment: 0.50, throttle: false);
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      if (node == _exitConfirmNode) {
        SystemNavigator.pop();
      } else {
        _closeExit();
      }
      return KeyEventResult.handled;
    }
    if (tvIsBackKey(key)) {
      _closeExit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<WidgetBuilder> _pageBuilders() {
    return <WidgetBuilder>[
      (_) => TvHomeScreen(
            focusTicket: _index == TvNavIndex.home ? _homeTicket : 0,
            bannerFocusTicket: _index == TvNavIndex.home ? _homeBannerTicket : 0,
            onMoveToNav: _showNav,
            onRequestExit: _showExit,
            onPlayerRouteOpen: _preparePlayerRoute,
            onPlayerRouteClosed: _restorePlayerRoute,
          ),
      (_) => TvDownloadsScreen(
            focusTicket: _index == TvNavIndex.download ? _contentTicket : 0,
            onMoveToNav: _showNav,
            onBackToNav: _returnToAccountMenuOrNav,
            onBackToHome: () => _enterContent(TvNavIndex.home),
            onPlayerRouteOpen: _preparePlayerRoute,
            onPlayerRouteClosed: _restorePlayerRoute,
          ),
      (_) => TvLibraryScreen(
            title: 'Histori',
            icon: Icons.history_rounded,
            favorites: false,
            focusTicket: _index == TvNavIndex.history ? _contentTicket : 0,
            onMoveToNav: _showNav,
            onBackToNav: _returnToAccountMenuOrNav,
            onBackToHome: () => _enterContent(TvNavIndex.home),
            onPlayerRouteOpen: _preparePlayerRoute,
            onPlayerRouteClosed: _restorePlayerRoute,
          ),
      (_) => TvLibraryScreen(
            title: 'Favorit',
            icon: Icons.favorite_rounded,
            favorites: true,
            focusTicket: _index == TvNavIndex.favorite ? _contentTicket : 0,
            onMoveToNav: _showNav,
            onBackToNav: _returnToAccountMenuOrNav,
            onBackToHome: () => _enterContent(TvNavIndex.home),
            onPlayerRouteOpen: _preparePlayerRoute,
            onPlayerRouteClosed: _restorePlayerRoute,
          ),
      (_) => TvAccountScreen(
            focusTicket: _index == TvNavIndex.account ? _accountTicket : 0,
            onMoveToNav: _showNav,
            onBackToNav: _showNav,
            onBackToHome: () => _enterContent(TvNavIndex.home),
            onOpenNavIndex: _openFromAccount,
          ),
      (_) => TvSearchScreen(
            focusTicket: _index == TvNavIndex.search ? _contentTicket : 0,
            onMoveToNav: _showNav,
            onBackToNav: _returnToAccountMenuOrNav,
            onBackToHome: () => _enterContent(TvNavIndex.home),
            onPlayerRouteOpen: _preparePlayerRoute,
            onPlayerRouteClosed: _restorePlayerRoute,
          ),
    ];
  }

  Widget _exitDialog() {
    if (!_exitOpen) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.66),
        alignment: Alignment.center,
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10243A), Color(0xFF07111F), Color(0xFF020617)]),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.cyan.withOpacity(0.26), width: 1.2),
            boxShadow: [const BoxShadow(color: Colors.black87, blurRadius: 38), BoxShadow(color: AppTheme.cyan.withOpacity(0.12), blurRadius: 30)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 62, height: 62, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.activeGradient, borderRadius: BorderRadius.circular(22), boxShadow: [TvFocusStyle.glow(0.12, 8)]), child: const Icon(Icons.logout_rounded, color: Colors.white, size: 32)),
              const SizedBox(height: 18),
              const Text('Keluar dari LiveGO?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 25, decoration: TextDecoration.none)),
              const SizedBox(height: 8),
              const Text('Tontonan terakhir disimpan otomatis. Kamu bisa lanjut lagi nanti.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSoft, fontSize: 13.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ExitDialogButton(node: _exitCancelNode, label: 'Tetap Menonton', primary: true, onKey: _exitKey, onTap: _closeExit),
                  const SizedBox(width: 16),
                  _ExitDialogButton(node: _exitConfirmNode, label: 'Keluar', primary: false, onKey: _exitKey, onTap: SystemNavigator.pop),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: AppTheme.bgDeep,
          body: PremiumShell(
            child: Focus(
              focusNode: _rootFocusNode,
              autofocus: true,
              skipTraversal: true,
              onKeyEvent: _rootKey,
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
                child: Stack(
                  children: [
                    Row(
                      children: [
                        TvSideNav(index: _index, mode: _navMode, focusNodes: _navNodes, onChanged: _openNavIndex, onOpenContent: _enterContent),
                        AnimatedContainer(duration: TvFocusStyle.normal, width: _navMode == TvSideNavMode.hidden ? 0 : 1, margin: const EdgeInsets.symmetric(vertical: 30), color: Colors.white.withOpacity(0.035)),
                        Expanded(
                          child: TvLazyIndexedStack(
                            index: _index,
                            builders: _pageBuilders(),
                            keepAliveIndexes: const <int>{TvNavIndex.home},
                          ),
                        ),
                      ],
                    ),
                    _exitDialog(),
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

class _ExitDialogButton extends StatelessWidget {
  final FocusNode node;
  final String label;
  final bool primary;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _ExitDialogButton({required this.node, required this.label, required this.primary, required this.onKey, required this.onTap});

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
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              width: 170,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: primary ? AppTheme.activeGradient : null,
                color: primary ? null : AppTheme.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: focused ? AppTheme.whiteGlow : (primary ? Colors.white.withOpacity(0.20) : AppTheme.border), width: focused ? 2 : 1),
                boxShadow: focused ? [TvFocusStyle.glow(0.08, 6)] : null,
              ),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            ),
          ),
        );
      },
    );
  }
}
