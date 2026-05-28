import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
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
      child: Text(text.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
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
        labelStyle: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w800),
        side: BorderSide(color: active ? AppTheme.cyan : Colors.white10),
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.cyan),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPlatforms = LiveGoCatalog.allPlatforms;
    final labels = LiveGoCatalog.labelsFor(allPlatforms);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
      children: [
        const Text('Pengaturan', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Atur bahasa, kualitas, source aktif, subtitle, dan mode LiveGo.', style: TextStyle(color: AppTheme.textSoft, height: 1.5)),
        _title('Bahasa'),
        Wrap(children: [
          for (final lang in ['id', 'en', 'th', 'ar'])
            _chip(lang.toUpperCase(), LiveGoSettings.language == lang, () => setState(() => LiveGoSettings.language = lang)),
        ]),
        _title('Kualitas Video'),
        Wrap(children: [
          for (final q in ['Auto', '720p', '480p'])
            _chip(q, LiveGoSettings.quality == q, () => setState(() => LiveGoSettings.quality = q)),
        ]),
        _title('Playback'),
        _switchTile('Auto Next Episode', 'Lanjut episode otomatis saat video selesai.', LiveGoSettings.autoNextEnabled, (v) => setState(() => LiveGoSettings.autoNextEnabled = v)),
        _switchTile('Subtitle Otomatis', 'Siapkan panel subtitle untuk source yang tersedia.', LiveGoSettings.subtitlesEnabled, (v) => setState(() => LiveGoSettings.subtitlesEnabled = v)),
        _switchTile('Mode TV Ringan', 'Kurangi efek berat untuk Android TV RAM kecil.', LiveGoSettings.lowEndTvMode, (v) => setState(() => LiveGoSettings.lowEndTvMode = v)),
        _title('Source Manager 32 Platform'),
        GlowContainer(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: List.generate(allPlatforms.length, (i) {
              final slug = allPlatforms[i];
              final active = LiveGoSettings.isPlatformActive(slug);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF0B2740).withOpacity(0.7) : AppTheme.surface2.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? AppTheme.cyan.withOpacity(0.55) : Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                        color: active ? null : Colors.white10,
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labels[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                          Text(slug, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: active,
                      onChanged: (_) => setState(() => LiveGoSettings.togglePlatform(slug)),
                      activeColor: AppTheme.cyan,
                    ),
                  ],
                ),
              );
            }),
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
