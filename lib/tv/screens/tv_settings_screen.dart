import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  void _setLang(String value) => setState(() => LiveGoSettings.language = value);
  void _setQuality(String value) => setState(() => LiveGoSettings.quality = value);
  void _setMode(String value) => setState(() => LiveGoSettings.layoutMode = value);
  void _setGrid(int value) => setState(() => LiveGoSettings.setTvHomeGrid(value));

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(56, 52, 56, 90),
        children: [
          const Text('Pengaturan TV', style: TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('Kontrol dibuat untuk remote: arah, enter, dan back.', style: TextStyle(color: AppTheme.textSoft, fontSize: 20)),
          const SizedBox(height: 30),
          _SectionGrid(
            title: 'Bahasa',
            children: [
              for (final lang in ['id', 'en', 'th', 'ar'])
                _SettingCard(title: lang.toUpperCase(), subtitle: 'Bahasa aplikasi', icon: Icons.language_rounded, active: LiveGoSettings.language == lang, onTap: () => _setLang(lang)),
            ],
          ),
          _SectionGrid(
            title: 'Kualitas Player',
            children: [
              for (final q in ['Auto Adaptive', 'Hemat Data', 'Normal', 'Kualitas Tinggi', '480p', '720p', '1080p'])
                _SettingCard(title: q, subtitle: 'Preferensi video', icon: Icons.high_quality_rounded, active: LiveGoSettings.quality == q, onTap: () => _setQuality(q)),
            ],
          ),
          _SectionGrid(
            title: 'Mode Tampilan',
            children: [
              for (final m in ['Auto', 'Mobile', 'TV'])
                _SettingCard(title: m, subtitle: 'Layout utama', icon: Icons.tv_rounded, active: LiveGoSettings.layoutMode == m, onTap: () => _setMode(m)),
            ],
          ),
          _SectionGrid(
            title: 'Grid TV',
            children: [
              for (final g in [4, 5, 6, 7, 8, 9, 10])
                _SettingCard(title: '$g Kolom', subtitle: 'Batas TV 10', icon: Icons.grid_view_rounded, active: LiveGoSettings.tvHomeGrid == g, onTap: () => _setGrid(g)),
            ],
          ),
          const SizedBox(height: 20),
          Text('${LiveGoSettings.supportedPlatforms.length} platform tersedia • ${LiveGoSettings.defaultPlatforms.length} default aktif.', style: const TextStyle(color: Colors.white70, fontSize: 18)),
        ],
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionGrid({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 2.2,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SettingCard({required this.title, required this.subtitle, required this.icon, required this.active, required this.onTap});

  @override
  State<_SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends State<_SettingCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final highlight = widget.active || focused;
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedScale(
          scale: focused ? 1.035 : 1,
          duration: const Duration(milliseconds: 130),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: widget.active ? const LinearGradient(colors: [Color(0xFF183455), Color(0xFF261B5B)]) : null,
              color: widget.active ? null : AppTheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.6) : Colors.white10), width: focused ? 2.3 : 1),
              boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.26), blurRadius: 20)] : null,
            ),
            child: Row(children: [
              Icon(widget.icon, color: highlight ? AppTheme.cyan : AppTheme.textSoft, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: highlight ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
              if (widget.active) const Icon(Icons.check_circle_rounded, color: AppTheme.cyan),
            ]),
          ),
        ),
      ),
    );
  }
}
