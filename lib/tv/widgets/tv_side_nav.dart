import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TvSideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final bool expanded;

  const TvSideNav({super.key, required this.index, required this.onChanged, required this.expanded});

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.download_rounded, 'Download'),
    (Icons.history_rounded, 'Histori'),
    (Icons.favorite_border_rounded, 'Favorit'),
    (Icons.person_rounded, 'Akun'),
    (Icons.search_rounded, 'Search'),
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
              itemBuilder: (_, i) {
                final active = i == index;
                return InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: active ? const LinearGradient(colors: [Color(0xFF183455), Color(0xFF261B5B)]) : null,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: active ? AppTheme.cyan.withOpacity(0.55) : Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(items[i].$1, color: active ? Colors.white : AppTheme.textSoft, size: 28),
                        if (expanded) ...[
                          const SizedBox(width: 14),
                          Expanded(child: Text(items[i].$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
