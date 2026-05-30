import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TvSideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const TvSideNav({super.key, required this.index, required this.onChanged});

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.download_rounded, 'Unduhan'),
    (Icons.history_rounded, 'Riwayat'),
    (Icons.favorite_border_rounded, 'Favorit'),
    (Icons.person_rounded, 'Akun'),
    (Icons.search_rounded, 'Cari'),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 118,
        margin: const EdgeInsets.fromLTRB(22, 22, 14, 22),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF07111F).withOpacity(0.94),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF1B3045)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 26)],
        ),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF0D1A2B),
                border: Border.all(color: const Color(0xFF233A52)),
              ),
              child: Container(
                margin: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                  boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.18), blurRadius: 18)],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 18),
            Container(width: 54, height: 1, color: Colors.white10),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _TvNavIcon(
                  icon: items[i].$1,
                  label: items[i].$2,
                  active: i == index,
                  autofocus: i == index,
                  onTap: () => onChanged(i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvNavIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool autofocus;
  final VoidCallback onTap;

  const _TvNavIcon({required this.icon, required this.label, required this.active, required this.autofocus, required this.onTap});

  @override
  State<_TvNavIcon> createState() => _TvNavIconState();
}

class _TvNavIconState extends State<_TvNavIcon> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.active || focused;
    return Tooltip(
      message: widget.label,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: (v) => setState(() => focused = v),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          focusColor: Colors.transparent,
          hoverColor: Colors.white10,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: focused ? 1.05 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 76,
              decoration: BoxDecoration(
                gradient: widget.active ? const LinearGradient(colors: [Color(0xFF123C56), Color(0xFF3B1B79)]) : null,
                color: widget.active ? null : const Color(0xFF0C1727),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.6) : Colors.white10), width: focused ? 2.2 : 1),
                boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.28), blurRadius: 18)] : null,
              ),
              child: Icon(widget.icon, color: selected ? Colors.white : Colors.white54, size: 31),
            ),
          ),
        ),
      ),
    );
  }
}
