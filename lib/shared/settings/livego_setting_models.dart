import 'package:flutter/material.dart';

import '../../core/livego_settings.dart';

enum LiveGoSettingId {
  layoutAuto,
  layoutMobile,
  layoutTv,
  backgroundPoster,
  cachePlayback,
  manualRotate,
  drmMode,
  tvPlayerEngine,
  cacheMaintenance,
  downloadNotice,
}

enum LiveGoSettingStyle { radio, tile }

class LiveGoSettingSection {
  final String title;
  final String? description;
  final List<LiveGoSettingItem> items;

  const LiveGoSettingSection({
    required this.title,
    required this.items,
    this.description,
  });
}

class LiveGoSettingItem {
  final LiveGoSettingId id;
  final LiveGoSettingStyle style;
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool active;
  final bool danger;
  final bool? switchValue;

  const LiveGoSettingItem._({
    required this.id,
    required this.style,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.active = false,
    this.danger = false,
    this.switchValue,
  });

  factory LiveGoSettingItem.radio({
    required LiveGoSettingId id,
    required String title,
    required bool active,
  }) {
    return LiveGoSettingItem._(
      id: id,
      style: LiveGoSettingStyle.radio,
      icon: active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
      title: title,
      subtitle: '',
      value: active ? 'AKTIF' : '',
      active: active,
    );
  }

  factory LiveGoSettingItem.tile({
    required LiveGoSettingId id,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    bool danger = false,
    bool? switchValue,
  }) {
    return LiveGoSettingItem._(
      id: id,
      style: LiveGoSettingStyle.tile,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      danger: danger,
      switchValue: switchValue,
    );
  }
}

class LiveGoSettingsMenuData {
  const LiveGoSettingsMenuData._();

  static const List<String> drmValues = <String>[
    'Auto',
    'Paksa L3',
    'Nonaktifkan Paksa L3',
  ];

  static List<LiveGoSettingSection> build({
    required bool tvLocked,
    bool cacheBusy = false,
  }) {
    final selectedLayout = tvLocked
        ? LiveGoSettings.layoutTv
        : LiveGoSettings.normalizeLayoutMode(LiveGoSettings.layoutMode);
    return <LiveGoSettingSection>[
      LiveGoSettingSection(
        title: 'Tampilan & Navigasi',
        description: tvLocked
            ? 'Auto/Handphone/Lanskap-TV tetap berjalan di TvApp karena runtime DTV dikunci ke mode TV.'
            : 'Auto: HP memakai tampilan handphone, Android TV memakai tampilan TV. '
                'Handphone: tampilan sentuh untuk HP. '
                'Lanskap-TV: tampilan lebar / TV-style; di HP hanya aktif jika dipilih manual.',
        items: <LiveGoSettingItem>[
          LiveGoSettingItem.radio(
            id: LiveGoSettingId.layoutAuto,
            title: 'Auto',
            active: selectedLayout == LiveGoSettings.layoutAuto,
          ),
          LiveGoSettingItem.radio(
            id: LiveGoSettingId.layoutMobile,
            title: 'Handphone',
            active: selectedLayout == LiveGoSettings.layoutMobile,
          ),
          LiveGoSettingItem.radio(
            id: LiveGoSettingId.layoutTv,
            title: 'Lanskap-TV',
            active: selectedLayout == LiveGoSettings.layoutTv,
          ),
          LiveGoSettingItem.tile(
            id: LiveGoSettingId.backgroundPoster,
            icon: Icons.wallpaper_rounded,
            title: 'Background Poster',
            subtitle: 'Tampilkan poster/backdrop sebagai ambience di detail, Home, dan player jika tersedia.',
            value: LiveGoSettings.backgroundPoster ? 'ON' : 'OFF',
            switchValue: LiveGoSettings.backgroundPoster,
          ),
        ],
      ),
      LiveGoSettingSection(
        title: 'Player',
        items: <LiveGoSettingItem>[
          LiveGoSettingItem.tile(
            id: LiveGoSettingId.cachePlayback,
            icon: Icons.play_circle_fill_rounded,
            title: 'Cache Playback',
            subtitle: 'Gunakan cache playback jika didukung player/source.',
            value: LiveGoSettings.cachePlayback ? 'ON' : 'OFF',
            switchValue: LiveGoSettings.cachePlayback,
          ),
          LiveGoSettingItem.tile(
            id: LiveGoSettingId.manualRotate,
            icon: Icons.screen_rotation_alt_rounded,
            title: 'Manual Rotate',
            subtitle: 'Tampilkan kontrol rotasi manual saat menonton.',
            value: LiveGoSettings.manualRotateButton ? 'ON' : 'OFF',
            switchValue: LiveGoSettings.manualRotateButton,
          ),
          LiveGoSettingItem.tile(
            id: LiveGoSettingId.drmMode,
            icon: Icons.enhanced_encryption_rounded,
            title: 'DRM Mode',
            subtitle: 'Mode kompatibilitas Widevine DRM.',
            value: LiveGoSettings.drmMode,
          ),
          LiveGoSettingItem.tile(
            id: LiveGoSettingId.tvPlayerEngine,
            icon: Icons.settings_input_component_rounded,
            title: 'TV Player Engine',
            subtitle: 'Pilih engine player default untuk TV (ExoPlayer atau Flutter Player).',
            value: LiveGoSettings.tvPlayerEngineOverride.isEmpty ? 'Default' : LiveGoSettings.tvPlayerEngineOverride,
          ),
        ],
      ),
      LiveGoSettingSection(
        title: 'Unduhan',
        items: <LiveGoSettingItem>[
          LiveGoSettingItem.tile(
            id: LiveGoSettingId.downloadNotice,
            icon: Icons.wifi_rounded,
            title: 'Download Wi-Fi Only',
            subtitle: 'Batasi download hanya saat memakai Wi-Fi.',
            value: LiveGoSettings.downloadWifiOnly ? 'Wi-Fi' : 'Bebas',
            switchValue: LiveGoSettings.downloadWifiOnly,
          ),
        ],
      ),
      LiveGoSettingSection(
        title: 'Perawatan',
        items: <LiveGoSettingItem>[
          LiveGoSettingItem.tile(
            id: LiveGoSettingId.cacheMaintenance,
            icon: Icons.delete_rounded,
            title: 'Cache Maintenance / Hapus Cache',
            subtitle: 'Bersihkan cache sementara Home/Player/Image/RAM. Riwayat, favorit, progress, settings, dan unduhan manual tetap aman.',
            value: cacheBusy ? 'PROSES' : 'BERSIHKAN',
            danger: true,
          ),
        ],
      ),
    ];
  }
}
