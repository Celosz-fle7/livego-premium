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
      child: SizedBox(
        width: 96,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 20, 10, 20),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF06101D).withOpacity(0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF172A3E)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 22)],
          ),
          child: Column(
            children: [
              _Logo(active: index == 0, onTap: () => onChanged(0)),
              const SizedBox(height: 14),
              Container(width: 42, height: 1, color: Colors.white10),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length - 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, raw) {
                    final i = raw + 1;
                    return _NavButton(
                      icon: items[i].$1,
                      label: items[i].$2,
                      active: i == index,
                      autofocus: i == index,
                      onTap: () => onChanged(i),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _Logo({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _NavButton(icon: Icons.play_arrow_rounded, label: 'Home', active: active, autofocus: active, onTap: onTap, logo: true);
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool autofocus;
  final VoidCallback onTap;
  final bool logo;

  const _NavButton({required this.icon, required this.label, required this.active, required this.autofocus, required this.onTap, this.logo = false});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = focused || widget.active;
    return Tooltip(
      message: widget.label,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: (v) => setState(() => focused = v),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            height: widget.logo ? 66 : 62,
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: [Color(0xFF123B54), Color(0xFF3C207E)]) : null,
              color: selected ? null : const Color(0xFF0A1422),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.7) : Colors.white10), width: focused ? 2.2 : 1),
            ),
            child: Icon(widget.icon, color: selected ? Colors.white : Colors.white54, size: widget.logo ? 32 : 28),
          ),
        ),
      ),
    );
  }
}
