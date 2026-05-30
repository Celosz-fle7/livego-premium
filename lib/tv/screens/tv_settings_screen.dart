import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  int tab = 0;
  final tabs = const ['Display', 'Player', 'Source'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 30, 32, 34),
      children: [
        _Header(
          tabs: tabs,
          selected: tab,
          onSelected: (v) => setState(() => tab = v),
        ),
        const SizedBox(height: 22),
        if (tab == 0) _displayTab() else if (tab == 1) _playerTab() else _sourceTab(),
      ],
    );
  }

  Widget _displayTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Tampilan & Navigasi'),
        _Panel(children: [
          _OptionRow(title: 'Mode Tampilan', subtitle: LiveGoSettings.layoutMode, icon: Icons.tv_rounded, onTap: () => _cycleLayout()),
          _OptionRow(title: 'Jumlah Kolom Grid', subtitle: '${LiveGoSettings.tvHomeGrid} kolom', icon: Icons.grid_view_rounded, onTap: () => _cycleGrid()),
        ]),
      ],
    );
  }

  Widget _playerTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Player'),
        _Panel(children: [
          _ToggleRow(title: 'Cache Playback', subtitle: 'Simpan potongan stream sementara agar pindah episode lebih stabil.', icon: Icons.cached_rounded, value: LiveGoSettings.cachePlayback, onChanged: (v) => setState(() => LiveGoSettings.cachePlayback = v)),
          _ToggleRow(title: 'Tombol Rotasi Manual', subtitle: 'Tampilkan tombol rotasi saat menonton di perangkat touch.', icon: Icons.screen_rotation_alt_rounded, value: LiveGoSettings.manualRotateButton, onChanged: (v) => setState(() => LiveGoSettings.manualRotateButton = v)),
          _OptionRow(title: 'Kualitas Default', subtitle: LiveGoSettings.quality, icon: Icons.high_quality_rounded, onTap: () => _cycleQuality()),
          _OptionRow(title: 'Widevine DRM', subtitle: LiveGoSettings.drmMode, icon: Icons.lock_rounded, onTap: () => _cycleDrm()),
        ]),
      ],
    );
  }

  Widget _sourceTab() {
    final platforms = LiveGoSettings.defaultPlatforms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Sumber Data'),
        _Panel(children: [
          _OptionRow(title: 'Default Platform', subtitle: LiveGoSettings.defaultPlatform, icon: Icons.layers_rounded, onTap: () => _cyclePlatform(platforms)),
          _OptionRow(title: 'Bahasa', subtitle: LiveGoSettings.language.toUpperCase(), icon: Icons.language_rounded, onTap: () => _cycleLanguage()),
          _OptionRow(title: 'Platform Aktif', subtitle: '${LiveGoSettings.activePlatforms.length} aktif', icon: Icons.apps_rounded, onTap: () {}),
          _DangerRow(title: 'Hapus Semua Cache', subtitle: 'Bersihkan cache streaming dan gambar.', icon: Icons.delete_rounded, onTap: () {}),
        ]),
      ],
    );
  }

  void _cycleLayout() {
    const values = ['Auto', 'Mobile', 'TV'];
    final next = values[(values.indexOf(LiveGoSettings.layoutMode) + 1) % values.length];
    setState(() => LiveGoSettings.layoutMode = next);
  }

  void _cycleGrid() {
    final next = LiveGoSettings.tvHomeGrid >= 10 ? 5 : LiveGoSettings.tvHomeGrid + 1;
    setState(() => LiveGoSettings.setTvHomeGrid(next));
  }

  void _cycleQuality() {
    const values = ['Auto Adaptive', '480p', '720p', '1080p'];
    final idx = values.indexOf(LiveGoSettings.quality);
    setState(() => LiveGoSettings.quality = values[(idx + 1) % values.length]);
  }

  void _cycleDrm() {
    const values = ['Auto', 'Paksa L3', 'Matikan'];
    final idx = values.indexOf(LiveGoSettings.drmMode);
    setState(() => LiveGoSettings.drmMode = values[(idx + 1) % values.length]);
  }

  void _cyclePlatform(List<String> values) {
    if (values.isEmpty) return;
    final idx = values.indexOf(LiveGoSettings.defaultPlatform);
    setState(() => LiveGoSettings.defaultPlatform = values[(idx + 1) % values.length]);
  }

  void _cycleLanguage() {
    const values = ['id', 'en', 'th', 'ar'];
    final idx = values.indexOf(LiveGoSettings.language);
    setState(() => LiveGoSettings.language = values[(idx + 1) % values.length]);
  }
}

class _Header extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  const _Header({required this.tabs, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0C2838), Color(0xFF0B0F1A)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF1F3B55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
            const SizedBox(width: 8),
            const Text('Pengaturan LiveGO', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          const Text('Atur tampilan, player, source, dan cache untuk Android TV.', style: TextStyle(color: AppTheme.textSoft, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(children: List.generate(tabs.length, (i) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _TabChip(text: tabs[i], active: i == selected, onTap: () => onSelected(i)),
          ))),
        ],
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.text, required this.active, required this.onTap});

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: widget.active ? const Color(0xFF12314A) : const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: focused || widget.active ? AppTheme.cyan : Colors.white10, width: focused ? 2 : 1),
          ),
          child: Text(widget.text, style: TextStyle(color: widget.active || focused ? Colors.white : AppTheme.textSoft, fontSize: 15, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0B1220).withOpacity(0.92), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF1C3046))),
      child: Column(children: children),
    );
  }
}

class _OptionRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _OptionRow({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(26),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 92,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: focused ? const Color(0xFF12314A) : Colors.transparent, borderRadius: BorderRadius.circular(22), border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2.2)),
          child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFF102033), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)), child: Icon(widget.icon, color: Colors.white, size: 28)),
            const SizedBox(width: 22),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 14.5, fontWeight: FontWeight.w600))])),
            Text(widget.subtitle, style: TextStyle(color: focused ? AppTheme.cyan : Colors.white70, fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.title, required this.subtitle, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SwitchLikeRow(title: title, subtitle: subtitle, icon: icon, value: value, onChanged: onChanged);
  }
}

class _SwitchLikeRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchLikeRow({required this.title, required this.subtitle, required this.icon, required this.value, required this.onChanged});

  @override
  State<_SwitchLikeRow> createState() => _SwitchLikeRowState();
}

class _SwitchLikeRowState extends State<_SwitchLikeRow> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: () => widget.onChanged(!widget.value),
        borderRadius: BorderRadius.circular(26),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 92,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: focused ? const Color(0xFF12314A) : Colors.transparent, borderRadius: BorderRadius.circular(22), border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2.2)),
          child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFF102033), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)), child: Icon(widget.icon, color: Colors.white, size: 28)),
            const SizedBox(width: 22),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 14.5, fontWeight: FontWeight.w600))])),
            Switch(value: widget.value, onChanged: widget.onChanged, activeColor: AppTheme.cyan),
          ]),
        ),
      ),
    );
  }
}

class _DangerRow extends _OptionRow {
  const _DangerRow({required super.title, required super.subtitle, required super.icon, required super.onTap});
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)));
}
