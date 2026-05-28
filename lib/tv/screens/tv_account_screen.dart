import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';

class TvAccountScreen extends StatelessWidget {
  const TvAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(150, 56, 56, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Akun LiveGo', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppTheme.cyan, AppTheme.purple])),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 56),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Penggemar LiveGo', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('Default platform: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()}', style: const TextStyle(color: AppTheme.textSoft, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _tile('Histori', '0', Icons.history_rounded),
              _tile('Favorit', '0', Icons.favorite_rounded),
              _tile('Platform', '${LiveGoSettings.defaultPlatforms.length}', Icons.apps_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: AppTheme.cyan, size: 40), const SizedBox(height: 18), Text(value, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w800))]),
    );
  }
}
