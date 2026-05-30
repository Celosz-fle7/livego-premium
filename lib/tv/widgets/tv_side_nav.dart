import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TvSideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final bool expanded;

  const TvSideNav({super.key, required this.index, required this.onChanged, required this.expanded});

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.history_rounded, 'Histori'),
    (Icons.search_rounded, 'Search'),
    (Icons.favorite_border_rounded, 'Favorit'),
    (Icons.person_rounded, 'Akun'),
    (Icons.settings_rounded, 'Setting'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: expanded ? 190 : 96,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF24344A)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 28)],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
              boxShadow: [BoxShadow(color: AppTheme.purple.withOpacity(0.35), blurRadius: 20)],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TvNavItem(
                icon: items[i].$1,
                label: items[i].$2,
                active: i == index,
                expanded: expanded,
                autofocus: i == index,
                onTap: () => onChanged(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final bool autofocus;
  final VoidCallback onTap;

  const _TvNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.autofocus,
    required this.onTap,
  });

  @override
  State<_TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<_TvNavItem> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final highlight = widget.active || focused;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        focusColor: Colors.transparent,
        hoverColor: Colors.white10,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            gradient: highlight ? const LinearGradient(colors: [Color(0xFF183455), Color(0xFF261B5B)]) : null,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.55) : Colors.white10),
              width: focused ? 2.2 : 1,
            ),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 18)] : null,
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: highlight ? Colors.white : AppTheme.textSoft, size: 28),
              if (widget.expanded) ...[
                const SizedBox(width: 14),
                Expanded(child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
