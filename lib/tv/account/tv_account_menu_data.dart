import 'package:flutter/material.dart';

enum TvAccountAction {
  sourceManager,
  history,
  favorite,
  download,
  displaySettings,
  cacheMaintenance,
  help,
  feedback,
  about,
  update,
}

class TvAccountMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final TvAccountAction action;

  const TvAccountMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.action,
  });
}

class TvAccountMenuData {
  const TvAccountMenuData._();

  static List<TvAccountMenuItem> build() {
    return const <TvAccountMenuItem>[
      TvAccountMenuItem(
        icon: Icons.history_rounded,
        title: 'Riwayat Tonton',
        subtitle: 'Lanjutkan tontonan yang terakhir dibuka di LiveGo.',
        badge: 'HISTORY',
        action: TvAccountAction.history,
      ),
      TvAccountMenuItem(
        icon: Icons.favorite_rounded,
        title: 'Favorit',
        subtitle: 'Buka koleksi channel dan konten favorit Anda.',
        badge: 'FAVORIT',
        action: TvAccountAction.favorite,
      ),
      TvAccountMenuItem(
        icon: Icons.download_rounded,
        title: 'Download',
        subtitle: 'Akses daftar unduhan yang tersimpan untuk ditonton.',
        badge: 'OFFLINE',
        action: TvAccountAction.download,
      ),
      TvAccountMenuItem(
        icon: Icons.tune_rounded,
        title: 'Pengaturan Tampilan',
        subtitle: 'Mode layout, poster, player, DRM, unduhan, dan cache.',
        badge: 'DISPLAY',
        action: TvAccountAction.displaySettings,
      ),
      TvAccountMenuItem(
        icon: Icons.layers_rounded,
        title: 'Kelola Sumber Data',
        subtitle: 'Atur LiveGO Source, bahasa, kategori, dan platform aktif.',
        badge: 'SOURCE',
        action: TvAccountAction.sourceManager,
      ),
      TvAccountMenuItem(
        icon: Icons.cleaning_services_rounded,
        title: 'Perawatan Cache',
        subtitle: 'Bersihkan cache gambar, streaming, dan RAM TV.',
        badge: 'CACHE',
        action: TvAccountAction.cacheMaintenance,
      ),
      TvAccountMenuItem(
        icon: Icons.system_update_alt_rounded,
        title: 'Periksa Update',
        subtitle: 'Cek versi terbaru dari build GitHub Actions.',
        badge: 'UPDATE',
        action: TvAccountAction.update,
      ),
      TvAccountMenuItem(
        icon: Icons.help_outline_rounded,
        title: 'Bantuan',
        subtitle: 'Panduan penggunaan LiveGo TV dengan remote.',
        badge: 'HELP',
        action: TvAccountAction.help,
      ),
      TvAccountMenuItem(
        icon: Icons.feedback_rounded,
        title: 'Kirim Feedback',
        subtitle: 'Kirim masukan dan laporan untuk pengalaman TV.',
        badge: 'FEEDBACK',
        action: TvAccountAction.feedback,
      ),
      TvAccountMenuItem(
        icon: Icons.info_outline_rounded,
        title: 'Tentang LiveGo',
        subtitle: 'Informasi LiveGo Premium, mode TV, dan status data.',
        badge: 'INFO',
        action: TvAccountAction.about,
      ),
    ];
  }
}
