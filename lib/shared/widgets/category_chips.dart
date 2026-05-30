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
      spacing: tv ? 12 : 12,
      runSpacing: tv ? 10 : 10,
      children: List.generate(items.length, (index) {
        final active = index == selected;
        return _FocusableChip(
          text: items[index],
          active: active,
          tv: tv,
          onTap: () => onSelected?.call(index),
        );
      }),
    );
  }
}

class _FocusableChip extends StatefulWidget {
  final String text;
  final bool active;
  final bool tv;
  final VoidCallback onTap;

  const _FocusableChip({
    required this.text,
    required this.active,
    required this.tv,
    required this.onTap,
  });

  @override
  State<_FocusableChip> createState() => _FocusableChipState();
}

class _FocusableChipState extends State<_FocusableChip> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final tv = widget.tv;

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        focusColor: Colors.transparent,
        hoverColor: Colors.white10,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: tv ? 22 : 20, vertical: tv ? 11 : 12),
          decoration: BoxDecoration(
            gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
            color: active ? null : AppTheme.surface.withOpacity(0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: focused
                  ? AppTheme.cyan
                  : (active ? Colors.transparent : const Color(0xFF26364B)),
              width: focused ? 2.2 : 1,
            ),
            boxShadow: focused
                ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 20)]
                : null,
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: active || focused ? Colors.white : AppTheme.textSoft,
              fontSize: tv ? 15 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
