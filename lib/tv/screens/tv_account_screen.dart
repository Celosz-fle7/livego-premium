import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import 'tv_settings_screen.dart';

class TvAccountScreen extends StatelessWidget {
  const TvAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(166, 42, 60, 60),
      children: [
        Container(
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(.92),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: const Color(0xFF263A55)),
          ),
          child: Row(
            children: [
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: AppTheme.cyan, width: 2), gradient: const LinearGradient(colors: [Color(0xFF123A50), Color(0xFF26153F)])),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 70),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Akun LiveGO', style: TextStyle(color: AppTheme.textSoft, fontSize: 18)),
                    const SizedBox(height: 6),
                    const Text('User Penggemar', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text('Default platform: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()}', style: const TextStyle(color: AppTheme.textSoft, fontSize: 19)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text('KOLEKSI CEPAT', style: TextStyle(color: AppTheme.textSoft, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 14),
        _TvListPanel(children: [
          _TvActionRow(icon: Icons.history_rounded, title: 'Riwayat', subtitle: 'Lanjutkan dari tontonan terakhir yang sudah sempat dibuka.', autofocus: true),
          _TvActionRow(icon: Icons.favorite_border_rounded, title: 'Favorit', subtitle: 'Buka daftar judul yang kamu simpan sebagai favorit.'),
          _TvActionRow(icon: Icons.settings_rounded, title: 'Pengaturan', subtitle: 'Atur tampilan, player, subtitle, dan source aktif.', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TvSettingsScreen()))),
        ]),
        const SizedBox(height: 28),
        const Text('APLIKASI & DUKUNGAN', style: TextStyle(color: AppTheme.textSoft, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 14),
        _TvListPanel(children: const [
          _TvActionRow(icon: Icons.download_rounded, title: 'Periksa Pembaruan', subtitle: 'Cek versi terbaru LiveGO dan pasang update jika tersedia.'),
          _TvActionRow(icon: Icons.info_outline_rounded, title: 'Tentang LiveGO', subtitle: 'LiveGO Premium • Anichin API • Android TV mode.'),
        ]),
      ],
    );
  }
}

class _TvListPanel extends StatelessWidget {
  final List<Widget> children;
  const _TvListPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F1724).withOpacity(.94), borderRadius: BorderRadius.circular(34), border: Border.all(color: const Color(0xFF23364A))),
      child: Column(children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const Divider(height: 1, color: Colors.white10, indent: 24, endIndent: 24),
        ]
      ]),
    );
  }
}

class _TvActionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool autofocus;
  final VoidCallback? onTap;

  const _TvActionRow({required this.icon, required this.title, required this.subtitle, this.autofocus = false, this.onTap});

  @override
  State<_TvActionRow> createState() => _TvActionRowState();
}

class _TvActionRowState extends State<_TvActionRow> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          decoration: BoxDecoration(
            color: focused ? const Color(0xFF143650) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 2.2 : 1),
          ),
          child: Row(
            children: [
              Container(width: 66, height: 66, decoration: BoxDecoration(color: const Color(0xFF132238), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2A425F))), child: Icon(widget.icon, color: Colors.white, size: 34)),
              const SizedBox(width: 24),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(widget.subtitle, style: const TextStyle(color: AppTheme.textSoft, fontSize: 17)),
              ])),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}
