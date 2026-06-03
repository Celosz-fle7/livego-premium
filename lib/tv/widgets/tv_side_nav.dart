import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../theme/tv_focus_style.dart';
import '../utils/tv_focus_utils.dart';

class TvNavItem {
  final IconData icon;
  final String label;

  const TvNavItem(this.icon, this.label);
}

enum TvSideNavMode { hidden, peek, focused }

class TvSideNav extends StatelessWidget {
  final int index;
  final TvSideNavMode mode;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onOpenContent;

  const TvSideNav({
    super.key,
    required this.index,
    required this.mode,
    required this.focusNodes,
    required this.onChanged,
    required this.onOpenContent,
  });

  static const items = [
    TvNavItem(Icons.home_rounded, 'Home'),
    TvNavItem(Icons.download_rounded, 'Unduhan'),
    TvNavItem(Icons.history_rounded, 'Histori'),
    TvNavItem(Icons.favorite_rounded, 'Favorit'),
    TvNavItem(Icons.person_rounded, 'Akun'),
    TvNavItem(Icons.search_rounded, 'Cari'),
  ];

  bool get _visible => mode != TvSideNavMode.hidden;
  bool get _focused => mode == TvSideNavMode.focused;

  int _safe(int value) {
    if (focusNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = focusNodes.length - 1;
    if (value > max) return max;
    return value;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  KeyEventResult _handleKey(int itemIndex, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      tvFocusComfort(focusNodes[_safe(itemIndex - 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      tvFocusComfort(focusNodes[_safe(itemIndex + 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
      onOpenContent(itemIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      onOpenContent(itemIndex);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: TvFocusStyle.normal,
        curve: Curves.linear,
        width: _visible ? 80 : 8,
        child: _visible ? _buildRail() : _HiddenGrip(active: index == 0),
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      margin: const EdgeInsets.fromLTRB(7, 30, 7, 30),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF2071326), Color(0xF2010409)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _focused ? TvFocusStyle.focusBlue.withOpacity(0.56) : AppTheme.borderSoft,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: [
          const BoxShadow(color: Colors.black54, blurRadius: 10),
          if (_focused) TvFocusStyle.glow(0.07, 6),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < TvSideNav.items.length; i++) ...[
            _NavIconButton(
              focusNode: focusNodes[i],
              icon: TvSideNav.items[i].icon,
              label: TvSideNav.items[i].label,
              active: i == index,
              railFocused: _focused,
              logo: i == 0,
              onTap: () => onOpenContent(i),
              onKey: (node, event) => _handleKey(i, event),
            ),
            if (i == 0) ...[
              const SizedBox(height: 8),
              Container(width: 31, height: 1, color: Colors.white10),
              const SizedBox(height: 8),
            ] else if (i < TvSideNav.items.length - 1)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _HiddenGrip extends StatelessWidget {
  final bool active;

  const _HiddenGrip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: TvFocusStyle.fast,
        width: 2,
        height: active ? 88 : 56,
        margin: const EdgeInsets.only(left: 1),
        decoration: BoxDecoration(
          color: active ? TvFocusStyle.focusBlue.withOpacity(0.18) : Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool active;
  final bool railFocused;
  final bool logo;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

  const _NavIconButton({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.active,
    required this.railFocused,
    required this.onTap,
    required this.onKey,
    this.logo = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final selected = focused || active;
        final size = 50.0;
        return Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 200),
          child: Focus(
            focusNode: focusNode,
            skipTraversal: true,
            autofocus: false,
            onKeyEvent: onKey,
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              focusColor: Colors.transparent,
              child: AnimatedContainer(
                duration: TvFocusStyle.fast,
                height: size,
                width: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: focused
                              ? [TvFocusStyle.focusBlue.withOpacity(0.16), AppTheme.surface3.withOpacity(0.96)]
                              : [AppTheme.surface2, AppTheme.surface],
                        )
                      : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: focused
                        ? TvFocusStyle.focusBlue
                        : (active ? TvFocusStyle.focusBlue.withOpacity(0.35) : Colors.transparent),
                    width: focused ? 2.0 : 1.0,
                  ),
                  boxShadow: focused ? [TvFocusStyle.glow(0.07, 5)] : null,
                ),
                child: Icon(
                  icon,
                  color: selected ? AppTheme.whiteGlow : Colors.white70,
                  size: logo ? 24 : 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
