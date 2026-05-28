import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class MobileBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const MobileBottomNav({super.key, required this.index, required this.onChanged});

  static const tabs = [
    (Icons.home_rounded, 'HOME'),
    (Icons.history_rounded, 'HISTORI'),
    (Icons.search_rounded, 'SEARCH'),
    (Icons.favorite_rounded, 'FAVORIT'),
    (Icons.person_rounded, 'AKUN'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF24344A)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = index == i;
            final tab = tabs[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF183455) : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: active ? Border.all(color: const Color(0xFF275F8C)) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab.$1, color: active ? Colors.white : AppTheme.textSoft, size: 24),
                      const SizedBox(height: 5),
                      Text(tab.$2, style: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
