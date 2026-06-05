import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../theme/tv_focus_style.dart';

class TvNavItem {
  final IconData icon;
  final String label;

  const TvNavItem(this.icon, this.label);
}

enum TvSideNavMode { hidden, focused }

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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: _visible ? 80 : 8,
        child: _visible ? _buildRail() : const _HiddenGrip(active: true),
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      margin: const EdgeInsets.fromLTRB(7, 30, 7, 30),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xF2071326),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _focused ? TvFocusStyle.focusBlue.withOpacity(0.48) : AppTheme.borderSoft,
          width: _focused ? 1.2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < TvSideNav.items.length; i++) ...[
            _NavIconButton(
              icon: TvSideNav.items[i].icon,
              label: TvSideNav.items[i].label,
              active: i == index,
              railFocused: _focused,
              logo: i == 0,
              onTap: () => onOpenContent(i),
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
      child: Container(
        width: 2,
        height: 88,
        margin: const EdgeInsets.only(left: 1),
        decoration: BoxDecoration(
          color: TvFocusStyle.focusBlue.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool railFocused;
  final bool logo;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.railFocused,
    required this.onTap,
    this.logo = false,
  });

  @override
  Widget build(BuildContext context) {
    final selected = active;
    final size = 50.0;
    return InkWell(
      canRequestFocus: false,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      focusColor: Colors.transparent,
      child: Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected && railFocused
                ? TvFocusStyle.focusBlue
                : (selected ? TvFocusStyle.focusBlue.withOpacity(0.30) : Colors.transparent),
            width: selected && railFocused ? 2.0 : 1.0,
          ),
        ),
        child: Icon(
          icon,
          color: selected ? AppTheme.whiteGlow : Colors.white70,
          size: logo ? 24 : 22,
        ),
      ),
    );
  }
}
