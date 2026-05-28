import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../shared/widgets/glow_container.dart';
import 'mobile_settings_screen.dart';

class MobileAccountScreen extends StatelessWidget {
  const MobileAccountScreen({super.key});

  Widget _stat(String value, String label) {
    return Expanded(
      child: GlowContainer(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .4)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
      child: Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 12)),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF132135),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2B4058)),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, height: 1.25)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppTheme.textSoft),
          ],
        ),
      ),
    );
  }

  Widget _menuGroup(BuildContext context, List<Widget> children) {
    return GlowContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(color: Color(0xFF24344A), height: 1),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
          children: [
            GlowContainer(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                      boxShadow: [BoxShadow(color: AppTheme.purple.withOpacity(0.3), blurRadius: 24)],
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 52),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RUANG PRIBADI', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .8)),
                        SizedBox(height: 8),
                        Text('Penggemar LiveGo', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        SizedBox(height: 6),
                        Text('Masuk cepat ke riwayat, favorit, pengaturan, dan update.', style: TextStyle(color: AppTheme.textSoft, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              _stat('${LiveGoLocalStore.history.length}', 'HISTORI'),
              const SizedBox(width: 10),
              _stat('${LiveGoLocalStore.favorites.length}', 'FAVORIT'),
              const SizedBox(width: 10),
              _stat('${LiveGoSettings.defaultPlatforms.length}', 'PLATFORM'),
            ]),
            _section('Koleksi Cepat'),
            _menuGroup(context, [
              _menu(context, Icons.history_rounded, 'Riwayat', 'Lanjutkan tontonan terakhir yang sudah dibuka.', () {}),
              _menu(context, Icons.favorite_border_rounded, 'Favorit', 'Buka daftar judul yang Anda simpan.', () {}),
              _menu(context, Icons.settings_rounded, 'Pengaturan', 'Atur tampilan, player, subtitle, dan source aktif.', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: MobileSettingsScreen()))));
              }),
            ]),
            _section('Aplikasi & Dukungan'),
            _menuGroup(context, [
              _menu(context, Icons.system_update_alt_rounded, 'Periksa Pembaruan', 'Cek versi terbaru LiveGo Premium.', () {}),
              _menu(context, Icons.share_rounded, 'Dukung LiveGo', 'Bantu maintenance dan eksperimen fitur baru.', () {}),
              _menu(context, Icons.send_rounded, 'Kirim Feedback', 'Laporkan bug, source, atau usulan fitur.', () {}),
              _menu(context, Icons.help_outline_rounded, 'Bantuan', 'Panduan singkat fitur utama LiveGo.', () {}),
            ]),
            _section('Info LiveGo'),
            _menuGroup(context, [
              _menu(context, Icons.info_outline_rounded, 'Tentang LiveGo', 'Streaming premium HP dan Android TV dengan source manager dinamis.', () {}),
            ]),
          ],
        );
      },
    );
  }
}
