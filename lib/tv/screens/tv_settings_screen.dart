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

  @override
  Widget build(BuildContext context) {
    final tabs = ['Display', 'Player', 'Source'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(166, 42, 60, 60),
      children: [
        Container(
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(color: AppTheme.surface.withOpacity(.92), borderRadius: BorderRadius.circular(38), border: Border.all(color: const Color(0xFF263A55))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _CircleButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
              const SizedBox(width: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0B1826), borderRadius: BorderRadius.circular(999)), child: const Text('CONTROL CENTER', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 24),
            const Text('Pengaturan LiveGO', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Rapikan mode tampilan, player, source, izin, dan cache dari satu tempat yang nyaman dipakai di Android TV.', style: TextStyle(color: AppTheme.textSoft, fontSize: 18)),
            const SizedBox(height: 22),
            Wrap(spacing: 12, children: List.generate(tabs.length, (i) => _TabPill(label: tabs[i], active: tab == i, onTap: () => setState(() => tab = i)))),
          ]),
        ),
        const SizedBox(height: 28),
        if (tab == 0) _displayTab(),
        if (tab == 1) _playerTab(),
        if (tab == 2) _sourceTab(),
      ],
    );
  }

  Widget _displayTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('TAMPILAN & NAVIGASI'),
      _Panel(children: [
        _SelectRow(title: 'Otomatis (Ikuti Hardware)', active: LiveGoSettings.layoutMode == 'Auto', autofocus: true, onTap: () => setState(() => LiveGoSettings.layoutMode = 'Auto')),
        _SelectRow(title: 'Smartphone / Tablet (Android)', active: LiveGoSettings.layoutMode == 'Mobile', onTap: () => setState(() => LiveGoSettings.layoutMode = 'Mobile')),
        _SelectRow(title: 'Android TV (Leanback Style)', active: LiveGoSettings.layoutMode == 'TV', onTap: () => setState(() => LiveGoSettings.layoutMode = 'TV')),
        _SliderRow(title: 'Jumlah Kolom Grid: ${LiveGoSettings.tvHomeGrid}', subtitle: 'Atur kepadatan poster TV dari 5 sampai 10 kolom.', value: LiveGoSettings.tvHomeGrid.toDouble(), min: 5, max: 10, onChanged: (v) => setState(() => LiveGoSettings.setTvHomeGrid(v.round()))),
      ]),
    ]);
  }

  Widget _playerTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('PLAYER'),
      _Panel(children: [
        _ToggleRow(icon: Icons.cached_rounded, title: 'Gunakan Cache Playback', subtitle: 'Simpan potongan stream sementara agar perpindahan playback lebih stabil.', value: LiveGoSettings.cachePlayback, autofocus: true, onChanged: (v) => setState(() => LiveGoSettings.cachePlayback = v)),
        _ToggleRow(icon: Icons.screen_rotation_alt_rounded, title: 'Tampilkan Tombol Rotasi Manual', subtitle: 'Tampilkan kontrol rotasi manual saat menonton di perangkat touch.', value: LiveGoSettings.manualRotateButton, onChanged: (v) => setState(() => LiveGoSettings.manualRotateButton = v)),
        _ValueRow(icon: Icons.hd_rounded, title: 'Kualitas Default', subtitle: 'Preferensi kualitas video untuk episode berikutnya.', value: LiveGoSettings.quality, onTap: _qualityDialog),
        _ValueRow(icon: Icons.lock_rounded, title: 'Kompatibilitas Widevine DRM', subtitle: 'Auto hanya memakai fallback kompatibilitas pada perangkat bermasalah.', value: LiveGoSettings.drmMode, onTap: _drmDialog),
      ]),
    ]);
  }

  Widget _sourceTab() {
    final platforms = LiveGoSettings.supportedPlatforms;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('SUMBER DATA'),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: platforms.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisExtent: 118, crossAxisSpacing: 16, mainAxisSpacing: 16),
        itemBuilder: (_, i) {
          final slug = platforms[i];
          final active = LiveGoSettings.isPlatformActive(slug);
          return _SourceCard(slug: slug, active: active, autofocus: i == 0, onTap: () => setState(() => LiveGoSettings.togglePlatform(slug)));
        },
      ),
      const SizedBox(height: 28),
      const _SectionLabel('PERAWATAN'),
      _Panel(children: const [
        _ValueRow(icon: Icons.delete_rounded, title: 'Hapus Semua Cache', subtitle: 'Bersihkan cache streaming dan gambar agar ruang penyimpanan tetap lega.', value: 'BERSIHKAN'),
      ]),
    ]);
  }

  Future<void> _qualityDialog() async {
    final value = await _choose('Kualitas Default', ['Auto', '480p', '720p', '1080p'], LiveGoSettings.quality);
    if (value != null) setState(() => LiveGoSettings.quality = value);
  }

  Future<void> _drmDialog() async {
    final value = await _choose('Mode DRM', ['Auto', 'Paksa L3', 'Native'], LiveGoSettings.drmMode);
    if (value != null) setState(() => LiveGoSettings.drmMode = value);
  }

  Future<String?> _choose(String title, List<String> values, String current) {
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: const Color(0xFF111B2B), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF2A3D59))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            ...values.map((e) => _DialogChoice(label: e, active: e == current, onTap: () => Navigator.pop(context, e))),
          ]),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(text, style: const TextStyle(color: AppTheme.textSoft, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1)));
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: const Color(0xFF0F1724).withOpacity(.94), borderRadius: BorderRadius.circular(34), border: Border.all(color: const Color(0xFF23364A))), child: Column(children: children));
}

class _TabPill extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.active, required this.onTap});
  @override
  State<_TabPill> createState() => _TabPillState();
}
class _TabPillState extends State<_TabPill> { bool focused = false; @override Widget build(BuildContext context) => FocusableActionDetector(onShowFocusHighlight: (v)=>setState(()=>focused=v), child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(999), child: AnimatedContainer(duration: const Duration(milliseconds:140), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), decoration: BoxDecoration(color: widget.active ? AppTheme.cyan.withOpacity(.25) : const Color(0xFF131C2A), borderRadius: BorderRadius.circular(999), border: Border.all(color: focused || widget.active ? AppTheme.cyan : Colors.white10, width: focused ? 2 : 1)), child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))); }

class _CircleButton extends StatelessWidget { final IconData icon; final VoidCallback onTap; const _CircleButton({required this.icon, required this.onTap}); @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: Container(width: 58, height: 58, decoration: const BoxDecoration(color: Color(0xFF0C1624), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 30))); }

class _SelectRow extends StatefulWidget { final String title; final bool active; final bool autofocus; final VoidCallback onTap; const _SelectRow({required this.title, required this.active, required this.onTap, this.autofocus=false}); @override State<_SelectRow> createState()=>_SelectRowState(); }
class _SelectRowState extends State<_SelectRow>{ bool focused=false; @override Widget build(BuildContext context)=>FocusableActionDetector(autofocus: widget.autofocus, onShowFocusHighlight:(v)=>setState(()=>focused=v), child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(24), child: AnimatedContainer(duration: const Duration(milliseconds:140), padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22), decoration: BoxDecoration(color: focused ? const Color(0xFF143650) : Colors.transparent, borderRadius: BorderRadius.circular(24), border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2)), child: Row(children:[Icon(widget.active ? Icons.radio_button_checked : Icons.radio_button_off, color: AppTheme.cyan, size: 30), const SizedBox(width: 22), Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))]))));}

class _SliderRow extends StatelessWidget { final String title, subtitle; final double value,min,max; final ValueChanged<double> onChanged; const _SliderRow({required this.title, required this.subtitle, required this.value, required this.min, required this.max, required this.onChanged}); @override Widget build(BuildContext context)=>Padding(padding: const EdgeInsets.all(26), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), Slider(value:value,min:min,max:max,divisions:(max-min).round(), onChanged:onChanged), Text(subtitle, style: const TextStyle(color: AppTheme.textSoft, fontSize: 15))])); }

class _ToggleRow extends StatefulWidget { final IconData icon; final String title, subtitle; final bool value, autofocus; final ValueChanged<bool> onChanged; const _ToggleRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, this.autofocus=false}); @override State<_ToggleRow> createState()=>_ToggleRowState(); }
class _ToggleRowState extends State<_ToggleRow>{ bool focused=false; @override Widget build(BuildContext context)=>FocusableActionDetector(autofocus: widget.autofocus, onShowFocusHighlight:(v)=>setState(()=>focused=v), child: InkWell(onTap:()=>widget.onChanged(!widget.value), borderRadius: BorderRadius.circular(28), child: AnimatedContainer(duration: const Duration(milliseconds:140), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: focused ? const Color(0xFF143650) : Colors.transparent, borderRadius: BorderRadius.circular(28), border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2)), child: Row(children:[_IconBox(widget.icon), const SizedBox(width:22), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height:6), Text(widget.subtitle, style: const TextStyle(color: AppTheme.textSoft, fontSize: 16))])), Switch(value:widget.value, onChanged:widget.onChanged, activeColor: AppTheme.cyan)])))); }

class _ValueRow extends StatefulWidget { final IconData icon; final String title, subtitle, value; final bool autofocus; final VoidCallback? onTap; const _ValueRow({required this.icon, required this.title, required this.subtitle, required this.value, this.onTap, this.autofocus=false}); @override State<_ValueRow> createState()=>_ValueRowState(); }
class _ValueRowState extends State<_ValueRow>{ bool focused=false; @override Widget build(BuildContext context)=>FocusableActionDetector(autofocus: widget.autofocus, onShowFocusHighlight:(v)=>setState(()=>focused=v), child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(28), child: AnimatedContainer(duration: const Duration(milliseconds:140), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: focused ? const Color(0xFF143650) : Colors.transparent, borderRadius: BorderRadius.circular(28), border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2)), child: Row(children:[_IconBox(widget.icon), const SizedBox(width:22), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height:6), Text(widget.subtitle, style: const TextStyle(color: AppTheme.textSoft, fontSize: 16))])), Text(widget.value.toUpperCase(), style: const TextStyle(color: AppTheme.cyan, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(width: 10), const Icon(Icons.arrow_forward_rounded, color: Colors.white38)])))); }

class _IconBox extends StatelessWidget { final IconData icon; const _IconBox(this.icon); @override Widget build(BuildContext context)=>Container(width:64,height:64,decoration:BoxDecoration(color: const Color(0xFF132238), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2A425F))), child: Icon(icon,color:Colors.white,size:32)); }

class _SourceCard extends StatefulWidget { final String slug; final bool active, autofocus; final VoidCallback onTap; const _SourceCard({required this.slug, required this.active, required this.onTap, this.autofocus=false}); @override State<_SourceCard> createState()=>_SourceCardState(); }
class _SourceCardState extends State<_SourceCard>{ bool focused=false; String _label(String v)=>v.split(RegExp(r'[_-]')).map((e)=>e.isEmpty?e:'${e[0].toUpperCase()}${e.substring(1)}').join(' '); @override Widget build(BuildContext context)=>FocusableActionDetector(autofocus: widget.autofocus, onShowFocusHighlight:(v)=>setState(()=>focused=v), child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(28), child: AnimatedContainer(duration: const Duration(milliseconds:140), padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: widget.active ? const Color(0xFF123650) : const Color(0xFF101827), borderRadius: BorderRadius.circular(28), border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(.45) : Colors.white12), width: focused ? 2.3 : 1)), child: Row(children:[Icon(widget.active?Icons.check_circle_rounded:Icons.radio_button_unchecked_rounded, color: widget.active?AppTheme.cyan:Colors.white38, size:32), const SizedBox(width:16), Expanded(child:Text(_label(widget.slug), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))), Text(widget.active?'ON':'OFF', style: TextStyle(color: widget.active?AppTheme.cyan:AppTheme.textSoft, fontWeight: FontWeight.w900))])))); }

class _DialogChoice extends StatefulWidget { final String label; final bool active; final VoidCallback onTap; const _DialogChoice({required this.label, required this.active, required this.onTap}); @override State<_DialogChoice> createState()=>_DialogChoiceState(); }
class _DialogChoiceState extends State<_DialogChoice>{ bool focused=false; @override Widget build(BuildContext context)=>FocusableActionDetector(autofocus: widget.active, onShowFocusHighlight:(v)=>setState(()=>focused=v), child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(20), child: AnimatedContainer(duration: const Duration(milliseconds:140), margin: const EdgeInsets.only(bottom:10), padding: const EdgeInsets.symmetric(horizontal:20, vertical:18), decoration: BoxDecoration(color: focused ? const Color(0xFF143650) : const Color(0xFF0F1724), borderRadius: BorderRadius.circular(20), border: Border.all(color: focused || widget.active ? AppTheme.cyan : Colors.white10, width: focused ? 2 : 1)), child: Row(children:[Icon(widget.active?Icons.play_arrow_rounded:Icons.circle_outlined, color: widget.active?AppTheme.cyan:Colors.white38), const SizedBox(width:12), Text(widget.label, style: const TextStyle(color:Colors.white, fontSize:20, fontWeight:FontWeight.w800))])))); }
