import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  int tab = 0;
  static const tabs = ['Display', 'Player', 'Source'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: DefaultTextStyle.merge(style: const TextStyle(decoration: TextDecoration.none), child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 30, 30),
        children: [
          _Header(tab: tab, onTab: (v) => setState(() => tab = v)),
          const SizedBox(height: 18),
          if (tab == 0) _display() else if (tab == 1) _player() else _source(),
        ],
      )),
    );
  }

  Widget _display() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('Tampilan'),
    _Panel(children: [
      _OptionRow(icon: Icons.tv_rounded, title: 'Mode Tampilan', value: LiveGoSettings.layoutMode, onTap: _cycleLayout),
      _OptionRow(icon: Icons.grid_view_rounded, title: 'Grid TV', value: '${LiveGoSettings.tvHomeGrid} kolom', onTap: _cycleGrid),
    ]),
  ]);

  Widget _player() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('Player'),
    _Panel(children: [
      _OptionRow(icon: Icons.high_quality_rounded, title: 'Kualitas Default', value: LiveGoSettings.quality, onTap: _cycleQuality),
      _ToggleRow(icon: Icons.cached_rounded, title: 'Cache Playback', value: LiveGoSettings.cachePlayback, onChanged: (v) => setState(() => LiveGoSettings.cachePlayback = v)),
      _ToggleRow(icon: Icons.screen_rotation_alt_rounded, title: 'Tombol Rotasi Manual', value: LiveGoSettings.manualRotateButton, onChanged: (v) => setState(() => LiveGoSettings.manualRotateButton = v)),
      _OptionRow(icon: Icons.lock_rounded, title: 'Widevine DRM', value: LiveGoSettings.drmMode, onTap: _cycleDrm),
    ]),
  ]);

  Widget _source() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('Sumber'),
    _Panel(children: [
      _OptionRow(icon: Icons.layers_rounded, title: 'Default Platform', value: LiveGoSettings.defaultPlatform, onTap: _cyclePlatform),
      _OptionRow(icon: Icons.language_rounded, title: 'Bahasa', value: LiveGoSettings.language.toUpperCase(), onTap: _cycleLanguage),
      _OptionRow(icon: Icons.apps_rounded, title: 'Platform Aktif', value: '${LiveGoSettings.activePlatforms.length} aktif', onTap: () {}),
      _OptionRow(icon: Icons.delete_rounded, title: 'Hapus Cache', value: 'Bersihkan', danger: true, onTap: () {}),
    ]),
  ]);

  void _cycleLayout() {
    const values = ['Auto', 'Mobile', 'TV'];
    final idx = values.indexOf(LiveGoSettings.layoutMode);
    setState(() => LiveGoSettings.layoutMode = values[(idx + 1) % values.length]);
  }

  void _cycleGrid() => setState(() => LiveGoSettings.setTvHomeGrid(LiveGoSettings.tvHomeGrid >= 10 ? 5 : LiveGoSettings.tvHomeGrid + 1));

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

  void _cyclePlatform() {
    final values = LiveGoSettings.defaultPlatforms;
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
  final int tab;
  final ValueChanged<int> onTab;
  const _Header({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B2634), Color(0xFF080D17)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF1E3850))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CircleButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 14),
          const Text('Pengaturan LiveGO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ]),
        const SizedBox(height: 8),
        const Text('Atur tampilan, player, source, dan cache untuk Android TV.', style: TextStyle(color: AppTheme.textSoft, fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
        const SizedBox(height: 14),
        Row(children: List.generate(_TvSettingsScreenState.tabs.length, (i) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _TabChip(text: _TvSettingsScreenState.tabs[i], active: i == tab, onTap: () => onTab(i)),
        ))),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.white), style: IconButton.styleFrom(backgroundColor: const Color(0xFF0A1422), fixedSize: const Size(46, 46)));
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
    return Focus(
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter || event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(color: widget.active ? const Color(0xFF12314A) : const Color(0xFF090F19), borderRadius: BorderRadius.circular(999), border: Border.all(color: focused || widget.active ? AppTheme.cyan : Colors.white10, width: focused ? 2 : 1)),
          child: Text(widget.text, style: TextStyle(color: focused || widget.active ? Colors.white : AppTheme.textSoft, fontSize: 14, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: const Color(0xFF09111E).withOpacity(0.94), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF1A2D43))), child: Column(children: children));
}

class _OptionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool danger;
  const _OptionRow({required this.icon, required this.title, required this.value, required this.onTap, this.danger = false});
  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? const Color(0xFFFF6B7A) : AppTheme.cyan;
    return Focus(
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter || event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 70,
          margin: const EdgeInsets.all(7),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: focused ? const Color(0xFF102F45) : Colors.transparent, borderRadius: BorderRadius.circular(18), border: Border.all(color: focused ? color : Colors.transparent, width: 2)),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF102033), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)), child: Icon(widget.icon, color: widget.danger ? color : Colors.white, size: 25)),
            const SizedBox(width: 18),
            Expanded(child: Text(widget.title, style: TextStyle(color: widget.danger ? color : Colors.white, fontSize: 19, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
            Text(widget.value, style: TextStyle(color: focused ? color : AppTheme.textSoft, fontSize: 14, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ]),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _OptionRow(icon: icon, title: title, value: value ? 'ON' : 'OFF', onTap: () => onChanged(!value));
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 9), child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1, decoration: TextDecoration.none)));
}
