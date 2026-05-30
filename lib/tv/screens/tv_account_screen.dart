import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import 'tv_settings_screen.dart';

class TvAccountScreen extends StatelessWidget {
  const TvAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 30, 32, 34),
      children: [
        _ProfileHeader(),
        const SizedBox(height: 24),
        const _SectionTitle('Koleksi Cepat'),
        _TvListPanel(children: [
          _TvActionRow(icon: Icons.history_rounded, title: 'Riwayat', subtitle: 'Lanjutkan tontonan terakhir yang sudah sempat dibuka.', onTap: () {}),
          _TvActionRow(icon: Icons.favorite_border_rounded, title: 'Favorit', subtitle: 'Buka daftar judul yang kamu simpan sebagai favorit.', onTap: () {}),
          _TvActionRow(icon: Icons.settings_rounded, title: 'Pengaturan', subtitle: 'Atur tampilan, player, subtitle, dan source aktif.', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TvSettingsScreen()))),
        ]),
        const SizedBox(height: 22),
        const _SectionTitle('Aplikasi'),
        _TvListPanel(children: [
          _TvActionRow(icon: Icons.download_rounded, title: 'Periksa Pembaruan', subtitle: 'Cek versi terbaru LiveGO dan pasang update jika tersedia.', onTap: () {}),
          _TvActionRow(icon: Icons.info_outline_rounded, title: 'Tentang LiveGO', subtitle: 'LiveGO Premium • Anichin API • Android TV mode.', onTap: () {}),
        ]),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 185,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0C2838), Color(0xFF0B0F1A)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF1F3B55)),
      ),
      child: Row(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.75)),
              gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 58),
          ),
          const SizedBox(width: 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Penggemar LiveGO', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Default platform: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()}', style: const TextStyle(color: AppTheme.textSoft, fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvListPanel extends StatelessWidget {
  final List<Widget> children;
  const _TvListPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withOpacity(0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF1C3046)),
      ),
      child: Column(children: children),
    );
  }
}

class _TvActionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _TvActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  State<_TvActionRow> createState() => _TvActionRowState();
}

class _TvActionRowState extends State<_TvActionRow> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(28),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 96,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: focused ? const Color(0xFF12314A) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2.2),
          ),
          child: Row(
            children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFF102033), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)), child: Icon(widget.icon, color: Colors.white, size: 30)),
              const SizedBox(width: 22),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 15, fontWeight: FontWeight.w600))])),
              Icon(Icons.arrow_forward_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    );
  }
}
