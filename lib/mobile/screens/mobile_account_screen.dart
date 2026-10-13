import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../shared/widgets/glow_container.dart';
import 'mobile_settings_screen.dart';
import 'mobile_library_screen.dart';
import 'mobile_downloads_screen.dart';
import '../update/mobile_update_screen.dart';

class MobileAccountScreen extends StatelessWidget {
  const MobileAccountScreen({super.key});

  Widget _stat(String value, String label) {
    return Expanded(
      child: GlowContainer(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .4)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 11)),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF132135),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2B4058)),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, height: 1.25)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            GlowContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                      boxShadow: [BoxShadow(color: AppTheme.purple.withOpacity(0.3), blurRadius: 24)],
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RUANG PRIBADI', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .8)),
                        SizedBox(height: 6),
                        Text('Penggemar LiveGo', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Masuk cepat ke riwayat, favorit, pengaturan, dan update.', style: TextStyle(color: AppTheme.textSoft, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _stat('${LiveGoLocalStore.history.length}', 'HISTORI'),
              const SizedBox(width: 8),
              _stat('${LiveGoLocalStore.favorites.length}', 'FAVORIT'),
              const SizedBox(width: 8),
              _stat('${LiveGoLocalStore.downloads.length}', 'DOWNLOAD'),
            ]),
            _section('Koleksi Cepat'),
            _menuGroup(context, [
              _menu(context, Icons.history_rounded, 'Riwayat', 'Lanjutkan tontonan terakhir yang sudah dibuka.', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: MobileLibraryScreen(title: 'Histori', icon: Icons.history_rounded, favorites: false)))));
              }),
              _menu(context, Icons.favorite_border_rounded, 'Favorit', 'Buka daftar judul yang Anda simpan.', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: MobileLibraryScreen(title: 'Favorit', icon: Icons.favorite_rounded, favorites: true)))));
              }),
              _menu(context, Icons.download_for_offline_rounded, 'Download', 'Lihat antrean dan episode yang tersimpan.', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: MobileDownloadsScreen()))));
              }),
              _menu(context, Icons.settings_rounded, 'Pengaturan', 'Atur tampilan, player, DRM, unduhan, dan cache.', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: MobileSettingsScreen()))));
              }),
            ]),
            _section('Aplikasi & Dukungan'),
            _menuGroup(context, [
              _menu(context, Icons.layers_rounded, 'Kelola Sumber Data', 'Pilih 6 platform Beranda, kategori, dan cek status server.', () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: SourceManagerScreen()))));
              }),
              _menu(context, Icons.system_update_alt_rounded, 'Periksa Pembaruan', 'Cek versi terbaru LiveGo Premium.', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileUpdateScreen()));
              }),
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
