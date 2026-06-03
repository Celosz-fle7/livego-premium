import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../shared/widgets/premium_shell.dart';
import 'screens/tv_account_screen.dart';
import 'screens/tv_downloads_screen.dart';
import 'screens/tv_home_screen.dart';
import 'screens/tv_library_screen.dart';
import 'screens/tv_search_screen.dart';
import 'utils/tv_focus_utils.dart';
import 'theme/tv_focus_style.dart';
import 'widgets/tv_side_nav.dart';

class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  static const int _homeIndex = 0;
  static const int _downloadIndex = 1;
  static const int _historyIndex = 2;
  static const int _favoriteIndex = 3;
  static const int _accountIndex = 4;
  static const int _searchIndex = 5;
  int _index = _homeIndex;
  TvSideNavMode _navMode = TvSideNavMode.hidden;
  int _homeTicket = 0;
  int _homeBannerTicket = 0;
  int _accountTicket = 0;
  int _placeholderTicket = 0;
  bool _returnToAccountMenuOnBack = false;

  bool _exitDialogOpen = false;
  bool _restoreHomeBannerAfterExitDialog = false;
  int _lastBackHandledMs = 0;
  int _suppressBackUntilMs = 0;
  late final List<FocusNode> _navNodes;
  late final FocusNode _exitCancelNode;
  late final FocusNode _exitConfirmNode;

  @override
  void initState() {
    super.initState();
    _navNodes = List.generate(
      TvSideNav.items.length,
      (i) => FocusNode(skipTraversal: true, debugLabel: 'tv-nav-$i'),
    );
    _exitCancelNode = FocusNode(skipTraversal: true, debugLabel: 'tv-exit-cancel');
    _exitConfirmNode = FocusNode(skipTraversal: true, debugLabel: 'tv-exit-confirm');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Start TV directly on the Home banner. The navbar is still one LEFT away,
    // but the first remote action does not wait on API/image loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _homeBannerTicket++);
    });
  }

  @override
  void dispose() {
    for (final node in _navNodes) {
      node.dispose();
    }
    _exitCancelNode.dispose();
    _exitConfirmNode.dispose();
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

  void _markBackHandled() {
    _lastBackHandledMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _suppressBackFor([int milliseconds = 900]) {
    final until = DateTime.now().millisecondsSinceEpoch + milliseconds;
    if (until > _suppressBackUntilMs) _suppressBackUntilMs = until;
    _markBackHandled();
  }

  void _prepareHomePlayerRoute() {
    // Player is a full-screen route. While it is open, the root TV app must
    // not interpret the same BACK press as a navbar command.
    _suppressBackFor(1200);
    _hideNav();
  }

  void _restoreHomeAfterPlayerRoute() {
    _suppressBackFor(1100);
    if (!mounted) return;
    setState(() {
      _returnToAccountMenuOnBack = false;
      _index = _homeIndex;
      _navMode = TvSideNavMode.hidden;
    });
  }

  void _prepareContentPlayerRoute() {
    // Same guard as Home, but keep the current TV page selected.
    _suppressBackFor(1200);
    _hideNav();
  }

  void _restoreContentAfterPlayerRoute() {
    _suppressBackFor(1100);
    if (!mounted) return;
    setState(() => _navMode = TvSideNavMode.hidden);
    _bumpContentTicket();
  }

  void _focusNavNode(int navIndex) {
    if (!mounted || _navNodes.isEmpty) return;
    final node = _navNodes[_safeNav(navIndex)];
    if (node.context != null) {
      tvFocus(node, alignment: 0.10);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(node, alignment: 0.10);
    });
  }

  void _focusCurrentNav() {
    if (_navNodes.isEmpty) return;
    if (_navMode != TvSideNavMode.focused) {
      setState(() => _navMode = TvSideNavMode.focused);
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNavNode(_index));
      return;
    }
    _focusNavNode(_index);
  }

  void _peekOrFocusNav() {
    // LEFT from content must land on the navbar immediately.
    // Peek-only made TV remote navigation feel like it needed two LEFT presses.
    _focusCurrentNav();
  }

  void _hideNav() {
    if (_navMode != TvSideNavMode.hidden) {
      setState(() => _navMode = TvSideNavMode.hidden);
    }
  }

  void _backToCurrentNav() {
    _markBackHandled();
    if (_returnToAccountMenuOnBack && _index != _accountIndex) {
      _returnToAccountMenuOnBack = false;
      setState(() {
        _index = _accountIndex;
        _navMode = TvSideNavMode.hidden;
        _accountTicket++;
      });
      return;
    }
    _focusCurrentNav();
  }

  void _openNavPage(int navIndex) {
    final safe = _safeNav(navIndex);
    setState(() {
      _returnToAccountMenuOnBack = false;
      _index = safe;
      _navMode = TvSideNavMode.focused;
    });
    _focusNavNode(safe);
  }

  void _backToHomeNav() {
    _markBackHandled();
    setState(() {
      _returnToAccountMenuOnBack = false;
      _index = _homeIndex;
      _navMode = TvSideNavMode.focused;
    });
    _focusNavNode(_homeIndex);
  }

  void _backToHomeBanner() {
    _markBackHandled();
    setState(() {
      _returnToAccountMenuOnBack = false;
      _index = _homeIndex;
      _navMode = TvSideNavMode.hidden;
      _homeBannerTicket++;
    });
  }

  void _returnToHomeLastFocus() {
    _markBackHandled();
    setState(() {
      _returnToAccountMenuOnBack = false;
      _index = _homeIndex;
      _navMode = TvSideNavMode.hidden;
      _homeTicket++;
    });
  }

  void _enterContent(int navIndex) {
    final safe = _safeNav(navIndex);
    _returnToAccountMenuOnBack = false;
    if (safe != _index) {
      setState(() {
        _index = safe;
        _navMode = TvSideNavMode.hidden;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (safe == _homeIndex) {
            setState(() => _homeBannerTicket++);
          } else {
            _bumpContentTicket();
          }
        }
      });
      return;
    }
    _hideNav();
    if (safe == _homeIndex) {
      setState(() => _homeBannerTicket++);
    } else {
      _bumpContentTicket();
    }
  }

  void _openFromAccountMenu(int navIndex) {
    final safe = _safeNav(navIndex);
    if (safe == _accountIndex) return;
    setState(() {
      _returnToAccountMenuOnBack = true;
      _index = safe;
      _navMode = TvSideNavMode.hidden;
      _placeholderTicket++;
    });
  }

  void _bumpContentTicket() {
    if (!mounted) return;
    setState(() {
      if (_index == _homeIndex) {
        _homeTicket++;
      } else if (_index == _accountIndex) {
        _accountTicket++;
      } else {
        _placeholderTicket++;
      }
    });
  }

  void _showExitDialog({bool restoreHomeBanner = false}) {
    if (_exitDialogOpen) return;
    setState(() {
      _exitDialogOpen = true;
      _restoreHomeBannerAfterExitDialog = restoreHomeBanner;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_exitCancelNode, alignment: 0.50);
    });
  }

  void _showExitDialogFromHome() {
    _markBackHandled();
    _showExitDialog(restoreHomeBanner: true);
  }

  void _closeExitDialog() {
    if (!_exitDialogOpen) return;
    final restoreHomeBanner = _restoreHomeBannerAfterExitDialog;
    setState(() {
      _exitDialogOpen = false;
      _restoreHomeBannerAfterExitDialog = false;
      if (restoreHomeBanner && _index == _homeIndex) {
        _homeBannerTicket++;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!restoreHomeBanner || _index != _homeIndex) _focusCurrentNav();
    });
  }

  void _handleBack() {
    // Android TV can deliver the same Back press through both Shortcuts
    // and PopScope. Guard it so one physical press produces one action.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 420) return;
    _lastBackHandledMs = now;

    if (now < _suppressBackUntilMs) {
      return;
    }

    if (_exitDialogOpen) {
      _closeExitDialog();
      return;
    }

    // If the focused Home banner misses the key through a route/root shortcut,
    // still show the exit popup. Other Home zones keep their own BACK ladder.
    if (!_navHasFocus) {
      if (_index == _homeIndex) {
        final focusedLabel = FocusManager.instance.primaryFocus?.debugLabel ?? '';
        if (focusedLabel == 'tv-home-banner') {
          _showExitDialog(restoreHomeBanner: true);
        } else {
          _returnToHomeLastFocus();
        }
        return;
      }
      if (_returnToAccountMenuOnBack && _index != _accountIndex) {
        _returnToAccountMenuOnBack = false;
        setState(() {
          _index = _accountIndex;
          _navMode = TvSideNavMode.hidden;
          _accountTicket++;
        });
        return;
      }
      _focusCurrentNav();
      return;
    }

    // BACK from the focused rail only hides the rail. If the rail is on the
    // first shortcut, return to the real Home banner, not the rail icon.
    if (_index == _homeIndex) {
      _backToHomeBanner();
    } else {
      _returnToHomeLastFocus();
    }
  }

  KeyEventResult _exitDialogKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      tvFocus(node == _exitCancelNode ? _exitConfirmNode : _exitCancelNode, alignment: 0.50);
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      if (node == _exitConfirmNode) {
        SystemNavigator.pop();
      } else {
        _closeExitDialog();
      }
      return KeyEventResult.handled;
    }

    if (_isBack(key)) {
      _markBackHandled();
      _closeExitDialog();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  List<Widget> _pages() {
    return [
      TvHomeScreen(
        focusTicket: _index == _homeIndex ? _homeTicket : 0,
        bannerFocusTicket: _index == _homeIndex ? _homeBannerTicket : 0,
        onMoveToNav: _peekOrFocusNav,
        onRequestExit: _showExitDialogFromHome,
        onPlayerRouteOpen: _prepareHomePlayerRoute,
        onPlayerRouteClosed: _restoreHomeAfterPlayerRoute,
      ),
      TvDownloadsScreen(
        focusTicket: _index == _downloadIndex ? _placeholderTicket : 0,
        onMoveToNav: _peekOrFocusNav,
        onBackToNav: _backToCurrentNav,
        onBackToHome: _returnToHomeLastFocus,
        onPlayerRouteOpen: _prepareContentPlayerRoute,
        onPlayerRouteClosed: _restoreContentAfterPlayerRoute,
      ),
      TvLibraryScreen(
        title: 'Histori',
        icon: Icons.history_rounded,
        favorites: false,
        focusTicket: _index == _historyIndex ? _placeholderTicket : 0,
        onMoveToNav: _peekOrFocusNav,
        onBackToNav: _backToCurrentNav,
        onBackToHome: _returnToHomeLastFocus,
        onPlayerRouteOpen: _prepareContentPlayerRoute,
        onPlayerRouteClosed: _restoreContentAfterPlayerRoute,
      ),
      TvLibraryScreen(
        title: 'Favorit',
        icon: Icons.favorite_rounded,
        favorites: true,
        focusTicket: _index == _favoriteIndex ? _placeholderTicket : 0,
        onMoveToNav: _peekOrFocusNav,
        onBackToNav: _backToCurrentNav,
        onBackToHome: _returnToHomeLastFocus,
        onPlayerRouteOpen: _prepareContentPlayerRoute,
        onPlayerRouteClosed: _restoreContentAfterPlayerRoute,
      ),
      TvAccountScreen(
        focusTicket: _index == _accountIndex ? _accountTicket : 0,
        onMoveToNav: _peekOrFocusNav,
        onBackToNav: _backToCurrentNav,
        onBackToHome: _returnToHomeLastFocus,
        onOpenNavIndex: _openFromAccountMenu,
      ),
      TvSearchScreen(
        focusTicket: _index == _searchIndex ? _placeholderTicket : 0,
        onMoveToNav: _peekOrFocusNav,
        onBackToNav: _backToCurrentNav,
        onBackToHome: _returnToHomeLastFocus,
        onPlayerRouteOpen: _prepareContentPlayerRoute,
        onPlayerRouteClosed: _restoreContentAfterPlayerRoute,
      ),
    ];
  }

  Widget _buildExitDialog() {
    if (!_exitDialogOpen) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.66),
        alignment: Alignment.center,
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10243A), Color(0xFF07111F), Color(0xFF020617)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.cyan.withOpacity(0.26), width: 1.2),
            boxShadow: [
              const BoxShadow(color: Colors.black87, blurRadius: 38),
              BoxShadow(color: AppTheme.cyan.withOpacity(0.12), blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.activeGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [TvFocusStyle.glow(0.12, 8)],
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 18),
              const Text(
                'Keluar dari LiveGO?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 25, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tontonan terakhir disimpan otomatis. Kamu bisa lanjut lagi nanti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSoft, fontSize: 13.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ExitDialogButton(
                    node: _exitCancelNode,
                    label: 'Tetap Menonton',
                    primary: true,
                    onKey: _exitDialogKey,
                    onTap: _closeExitDialog,
                  ),
                  const SizedBox(width: 16),
                  _ExitDialogButton(
                    node: _exitConfirmNode,
                    label: 'Keluar',
                    primary: false,
                    onKey: _exitDialogKey,
                    onTap: SystemNavigator.pop,
                  ),
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
                        TvSideNav(
                          index: _index,
                          mode: _navMode,
                          focusNodes: _navNodes,
                          onChanged: _openNavPage,
                          onOpenContent: _enterContent,
                        ),
                        AnimatedContainer(
                          duration: TvFocusStyle.normal,
                          width: _navMode == TvSideNavMode.hidden ? 0 : 1,
                          margin: const EdgeInsets.symmetric(vertical: 30),
                          color: Colors.white.withOpacity(0.035),
                        ),
                        Expanded(
                          child: RepaintBoundary(
                            child: IndexedStack(index: _index, children: _pages()),
                          ),
                        ),
                      ],
                    ),
                    _buildExitDialog(),
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

class _ExitDialogButton extends StatelessWidget {
  final FocusNode node;
  final String label;
  final bool primary;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _ExitDialogButton({
    required this.node,
    required this.label,
    required this.primary,
    required this.onKey,
    required this.onTap,
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
          autofocus: false,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              height: 52,
              constraints: const BoxConstraints(minWidth: 156),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: primary ? AppTheme.activeGradient : null,
                color: primary ? null : AppTheme.danger.withOpacity(focused ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: focused ? AppTheme.whiteGlow : (primary ? Colors.white.withOpacity(0.16) : AppTheme.danger.withOpacity(0.34)),
                  width: focused ? 2 : 1,
                ),
                boxShadow: focused ? [primary ? TvFocusStyle.glow(0.10, 8) : BoxShadow(color: AppTheme.danger.withOpacity(0.16), blurRadius: 8)] : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: primary || focused ? Colors.white : AppTheme.danger.withOpacity(0.95),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
