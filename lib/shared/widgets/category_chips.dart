import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class CategoryChips extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int>? onSelected;
  final bool tv;

  const CategoryChips({super.key, required this.items, this.selected = 0, this.onSelected, this.tv = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: tv ? 14 : 12,
      runSpacing: tv ? 12 : 10,
      children: List.generate(items.length, (index) {
        final active = index == selected;
        return GestureDetector(
          onTap: () => onSelected?.call(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: tv ? 26 : 20, vertical: tv ? 14 : 12),
            decoration: BoxDecoration(
              gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
              color: active ? null : AppTheme.surface.withOpacity(0.82),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? Colors.transparent : const Color(0xFF26364B)),
            ),
            child: Text(
              items[index],
              style: TextStyle(
                color: active ? Colors.white : AppTheme.textSoft,
                fontSize: tv ? 16 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }),
    );
  }
}
