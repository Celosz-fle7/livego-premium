import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class SimplePage extends StatelessWidget {
  final String title;
  final IconData icon;
  const SimplePage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF26364B)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.cyan, size: 64),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Premium module siap disambungkan ke API produksi.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSoft)),
          ],
        ),
      ),
    );
  }
}
