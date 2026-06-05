import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvAccountMiniStat extends StatelessWidget {
  final String value;
  final String label;

  const TvAccountMiniStat({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSoft)),
      child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10, fontWeight: FontWeight.w800, decoration: TextDecoration.none))]),
    );
  }
}
