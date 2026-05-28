import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  Widget _chip(String text, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 14, bottom: 14),
      child: ActionChip(
        onPressed: onTap,
        label: Text(text),
        backgroundColor: active ? const Color(0xFF183455) : AppTheme.surface2,
        side: BorderSide(color: active ? AppTheme.cyan : Colors.white10),
        labelStyle: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(150, 56, 56, 80),
      children: [
        const Text('Pengaturan TV', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        const Text('Konfigurasi LiveGo untuk HP dan TV.', style: TextStyle(color: AppTheme.textSoft, fontSize: 18)),
        _section('Bahasa'),
        Wrap(children: [for (final lang in ['id', 'en', 'th', 'ar']) _chip(lang.toUpperCase(), LiveGoSettings.language == lang, () => setState(() => LiveGoSettings.language = lang))]),
        _section('Default 6 Platform'),
        Wrap(children: [for (final p in LiveGoSettings.defaultPlatforms) _chip(p, LiveGoSettings.defaultPlatform == p, () => setState(() => LiveGoSettings.defaultPlatform = p))]),
        _section('Kualitas'),
        Wrap(children: [for (final q in ['Auto', '720p', '480p']) _chip(q, LiveGoSettings.quality == q, () => setState(() => LiveGoSettings.quality = q))]),
        _section('Mode'),
        Wrap(children: [for (final m in ['Auto', 'Mobile', 'TV']) _chip(m, LiveGoSettings.layoutMode == m, () => setState(() => LiveGoSettings.layoutMode = m))]),
        const SizedBox(height: 24),
        Text('${LiveGoSettings.supportedPlatforms.length} platform tersedia • ${LiveGoSettings.defaultPlatforms.length} default aktif sementara.', style: const TextStyle(color: Colors.white70, fontSize: 18)),
      ],
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 34, 0, 16),
      child: Text(text.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    );
  }
}
