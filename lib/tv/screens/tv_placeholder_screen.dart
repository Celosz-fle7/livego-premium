import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TvPlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String subtitle;

  const TvPlaceholderScreen({super.key, required this.title, required this.icon, this.subtitle = 'LiveGo Premium TV mode'});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(166, 60, 60, 60),
      children: [
        Container(
          padding: const EdgeInsets.all(42),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple])),
                child: Icon(icon, color: Colors.white, size: 56),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSoft, fontSize: 20, height: 1.3)),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
