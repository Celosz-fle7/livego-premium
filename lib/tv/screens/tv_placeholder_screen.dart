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
        width: 430,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220).withOpacity(0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF1F3B55)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.cyan, size: 68),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('LiveGO Premium TV mode', style: TextStyle(color: AppTheme.textSoft, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
