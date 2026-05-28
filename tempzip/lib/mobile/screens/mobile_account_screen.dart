import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../shared/widgets/glow_container.dart';
import 'mobile_settings_screen.dart';

class MobileAccountScreen extends StatelessWidget {
  const MobileAccountScreen({super.key});

  Widget _stat(String value, String label) {
    return Expanded(
      child: GlowContainer(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: GlowContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSoft),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
      children: [
        Row(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                boxShadow: [BoxShadow(color: AppTheme.purple.withOpacity(0.35), blurRadius: 20)],
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Penggemar LiveGo', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text('Mode tamu premium aktif', style: TextStyle(color: AppTheme.textSoft)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(children: [_stat('0', 'HISTORI'), const SizedBox(width: 10), _stat('0', 'FAVORIT'), const SizedBox(width: 10), _stat('${LiveGoSettings.defaultPlatforms.length}', 'PLATFORM')]),
        const SizedBox(height: 26),
        _menu(context, Icons.settings_rounded, 'Pengaturan', 'Bahasa, platform, kualitas, mode tampilan', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: MobileSettingsScreen()))));
        }),
        _menu(context, Icons.source_rounded, 'Sumber Aktif', 'Default: ${LiveGoSettings.defaultPlatform}', () {}),
        _menu(context, Icons.cleaning_services_rounded, 'Bersihkan Cache', 'Hapus cache sementara aplikasi', () {}),
        _menu(context, Icons.info_outline_rounded, 'Tentang LiveGo', 'LiveGo Premium • HP dan TV', () {}),
      ],
    );
  }
}
