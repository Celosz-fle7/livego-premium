import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';

class TvAccountScreen extends StatelessWidget {
  const TvAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(56, 52, 56, 80),
        children: [
          const Text('Akun LiveGo', style: TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.w900)),
          const SizedBox(height: 26),
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppTheme.cyan, AppTheme.purple])),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 60),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Penggemar LiveGo', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text('Default platform: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()}', style: const TextStyle(color: AppTheme.textSoft, fontSize: 20)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 1.55,
            children: [
              _TvAccountTile(label: 'Histori', value: '0', icon: Icons.history_rounded, autofocus: true),
              _TvAccountTile(label: 'Favorit', value: '0', icon: Icons.favorite_rounded),
              _TvAccountTile(label: 'Platform', value: '${LiveGoSettings.defaultPlatforms.length}', icon: Icons.apps_rounded),
              const _TvAccountTile(label: 'Pengaturan', value: 'TV', icon: Icons.settings_rounded),
              const _TvAccountTile(label: 'Cache', value: 'Siap', icon: Icons.storage_rounded),
              const _TvAccountTile(label: 'Versi', value: '1.0', icon: Icons.info_outline_rounded),
              const _TvAccountTile(label: 'Mode', value: 'Remote', icon: Icons.settings_remote_rounded),
              const _TvAccountTile(label: 'Status', value: 'Online', icon: Icons.cloud_done_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _TvAccountTile extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool autofocus;
  const _TvAccountTile({required this.label, required this.value, required this.icon, this.autofocus = false});

  @override
  State<_TvAccountTile> createState() => _TvAccountTileState();
}

class _TvAccountTileState extends State<_TvAccountTile> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: AnimatedScale(
        scale: focused ? 1.04 : 1,
        duration: const Duration(milliseconds: 140),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: focused ? AppTheme.cyan : Colors.white10, width: focused ? 2.4 : 1),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.28), blurRadius: 22)] : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: AppTheme.cyan, size: 42),
            const SizedBox(height: 16),
            Text(widget.value, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(widget.label, style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w800, fontSize: 17)),
          ]),
        ),
      ),
    );
  }
}
