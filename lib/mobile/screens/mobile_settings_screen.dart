import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../shared/widgets/glow_container.dart';

class MobileSettingsScreen extends StatefulWidget {
  const MobileSettingsScreen({super.key});

  @override
  State<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSoft,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _chip(String text, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 10),
      child: ChoiceChip(
        selected: active,
        label: Text(text),
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF183455),
        backgroundColor: AppTheme.surface2,
        labelStyle: TextStyle(
          color: active ? Colors.white : AppTheme.textSoft,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: active ? AppTheme.cyan : Colors.white10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
      children: [
        const Text(
          'Pengaturan',
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Atur bahasa, platform default, kualitas, dan mode tampilan LiveGo.',
          style: TextStyle(color: AppTheme.textSoft, height: 1.5),
        ),
        _title('Bahasa'),
        Wrap(
          children: [
            for (final lang in ['id', 'en', 'th', 'ar'])
              _chip(lang.toUpperCase(), LiveGoSettings.language == lang, () {
                setState(() => LiveGoSettings.language = lang);
              }),
          ],
        ),
        _title('Default 6 Platform'),
        GlowContainer(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            children: [
              for (final platform in LiveGoSettings.defaultPlatforms)
                _chip(platform, LiveGoSettings.defaultPlatform == platform, () {
                  setState(() => LiveGoSettings.defaultPlatform = platform);
                }),
            ],
          ),
        ),
        _title('Kualitas Video'),
        Wrap(
          children: [
            for (final q in ['Auto', '720p', '480p'])
              _chip(q, LiveGoSettings.quality == q, () {
                setState(() => LiveGoSettings.quality = q);
              }),
          ],
        ),
        _title('Mode Tampilan'),
        Wrap(
          children: [
            for (final mode in ['Auto', 'Mobile', 'TV'])
              _chip(mode, LiveGoSettings.layoutMode == mode, () {
                setState(() => LiveGoSettings.layoutMode = mode);
              }),
          ],
        ),
        _title('Platform Didukung'),
        GlowContainer(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${LiveGoSettings.supportedPlatforms.length} platform siap dikoneksikan. Default aktif sementara: ${LiveGoSettings.defaultPlatforms.length}.',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => setState(LiveGoSettings.reset),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Reset Pengaturan'),
        ),
      ],
    );
  }
}
