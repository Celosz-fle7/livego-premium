import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

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
    TvNavItem(Icons.history_rounded, 'Histori'),
    TvNavItem(Icons.search_rounded, 'Cari'),
    TvNavItem(Icons.favorite_rounded, 'Favorit'),
    TvNavItem(Icons.download_rounded, 'Unduhan'),
    TvNavItem(Icons.person_rounded, 'Akun'),
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

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      focusNodes[_safe(itemIndex - 1)].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      focusNodes[_safe(itemIndex + 1)].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
      onOpenContent(itemIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      focusNodes[_safe(itemIndex)].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: _visible ? 74 : 16,
        child: _visible ? _buildRail() : _HiddenGrip(active: index == 0),
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF2071326), Color(0xF2010409)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _focused ? AppTheme.cyan.withOpacity(0.42) : AppTheme.borderSoft,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: [
          const BoxShadow(color: Colors.black87, blurRadius: 16),
          if (_focused) BoxShadow(color: AppTheme.cyan.withOpacity(0.14), blurRadius: 26, spreadRadius: 1),
        ],
      ),
      child: Column(
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
        duration: const Duration(milliseconds: 160),
        width: 4,
        height: active ? 120 : 80,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: active ? AppTheme.cyan.withOpacity(0.32) : Colors.white.withOpacity(0.08),
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
        final size = logo ? 50.0 : 47.0;
        return Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 500),
          child: Focus(
            focusNode: focusNode,
            skipTraversal: true,
            autofocus: false,
            onKeyEvent: onKey,
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap,
              borderRadius: BorderRadius.circular(15),
              focusColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                height: size,
                width: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: focused
                              ? [AppTheme.cyan.withOpacity(0.26), AppTheme.purple.withOpacity(0.18)]
                              : [AppTheme.surface2, AppTheme.surface],
                        )
                      : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: focused
                        ? AppTheme.cyan.withOpacity(0.98)
                        : (active ? AppTheme.cyan.withOpacity(0.30) : Colors.transparent),
                    width: focused ? 2 : 1,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(color: AppTheme.cyan.withOpacity(0.24), blurRadius: 18, spreadRadius: 1),
                          BoxShadow(color: AppTheme.purple.withOpacity(0.10), blurRadius: 28),
                        ]
                      : null,
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
