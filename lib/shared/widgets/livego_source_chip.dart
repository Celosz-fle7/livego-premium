import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class LiveGoSourceChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const LiveGoSourceChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: active,
        label: Text(label),
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.cyan,
        backgroundColor: AppTheme.surface2,
        labelStyle: TextStyle(
          color: active ? AppTheme.bg : AppTheme.textSoft,
          fontWeight: FontWeight.bold,
        ),
        side: BorderSide(
          color: active
              ? AppTheme.cyan
              : AppTheme.border,
        ),
      ),
    );
  }
}
