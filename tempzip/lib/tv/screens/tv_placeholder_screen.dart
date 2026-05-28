import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TvPlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const TvPlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(42),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.cyan, size: 96),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text('LiveGo Premium TV mode', style: TextStyle(color: AppTheme.textSoft, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
