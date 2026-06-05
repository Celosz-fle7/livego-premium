import 'package:flutter/material.dart';

enum TvAccountAction {
  sourceManager,
  displaySettings,
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
        icon: Icons.tune_rounded,
        title: 'Pengaturan Tampilan',
        subtitle: 'Mode tampilan, grid, ukuran poster, dan preferensi layar.',
        badge: 'DISPLAY',
        action: TvAccountAction.displaySettings,
      ),
      TvAccountMenuItem(
        icon: Icons.layers_rounded,
        title: 'Kelola Sumber Data',
        subtitle: 'Atur Anichin, bahasa, kategori, dan platform aktif.',
        badge: 'SOURCE',
        action: TvAccountAction.sourceManager,
      ),
      TvAccountMenuItem(
        icon: Icons.info_outline_rounded,
        title: 'Tentang Aplikasi',
        subtitle: 'Informasi LiveGo Premium, mode TV, dan status data.',
        badge: 'INFO',
        action: TvAccountAction.about,
      ),
      TvAccountMenuItem(
        icon: Icons.system_update_alt_rounded,
        title: 'Periksa Update',
        subtitle: 'Cek versi terbaru dari build GitHub.',
        badge: 'UPDATE',
        action: TvAccountAction.update,
      ),
    ];
  }
}
