import 'package:flutter/material.dart';

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
        selectedColor: const Color(0xFF08D9FF),
        backgroundColor: const Color(0xFF141927),
        labelStyle: TextStyle(
          color: active ? Colors.black : Colors.white70,
          fontWeight: FontWeight.bold,
        ),
        side: BorderSide(
          color: active
              ? const Color(0xFF08D9FF)
              : Colors.white.withOpacity(0.10),
        ),
      ),
    );
  }
}
