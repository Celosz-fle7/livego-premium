import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/livego_local_store.dart';

enum TvAccountAction {
  sourceManager,
  history,
  favorite,
  download,
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

  static ValueListenable<int> get versionListenable => LiveGoLocalStore.version;

  static List<TvAccountMenuItem> build() {
    return <TvAccountMenuItem>[
      const TvAccountMenuItem(
        icon: Icons.layers_rounded,
        title: 'Kelola Sumber Data',
        subtitle: 'Atur Anichin, bahasa, kategori, dan platform aktif.',
        badge: 'SOURCE',
        action: TvAccountAction.sourceManager,
      ),
      TvAccountMenuItem(
        icon: Icons.history_rounded,
        title: 'Riwayat Tontonan',
        subtitle: 'Buka histori tontonan dari navbar TV.',
        badge: '${LiveGoLocalStore.history.length}',
        action: TvAccountAction.history,
      ),
      TvAccountMenuItem(
        icon: Icons.favorite_rounded,
        title: 'Favorit',
        subtitle: 'Daftar konten yang kamu simpan.',
        badge: '${LiveGoLocalStore.favorites.length}',
        action: TvAccountAction.favorite,
      ),
      TvAccountMenuItem(
        icon: Icons.download_rounded,
        title: 'Download',
        subtitle: 'Kelola unduhan dan episode offline.',
        badge: '${LiveGoLocalStore.downloads.length}',
        action: TvAccountAction.download,
      ),
      const TvAccountMenuItem(
        icon: Icons.tune_rounded,
        title: 'Pengaturan Tampilan',
        subtitle: 'Mode tampilan, grid, ukuran poster, dan preferensi layar.',
        badge: 'DISPLAY',
        action: TvAccountAction.displaySettings,
      ),
      const TvAccountMenuItem(
        icon: Icons.info_outline_rounded,
        title: 'Tentang Aplikasi',
        subtitle: 'Informasi LiveGo Premium, mode TV, dan status data.',
        badge: 'INFO',
        action: TvAccountAction.about,
      ),
      const TvAccountMenuItem(
        icon: Icons.system_update_alt_rounded,
        title: 'Periksa Update',
        subtitle: 'Cek versi terbaru dari build GitHub.',
        badge: 'UPDATE',
        action: TvAccountAction.update,
      ),
    ];
  }
}
