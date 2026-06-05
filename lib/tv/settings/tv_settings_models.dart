part of 'tv_settings_screen.dart';

class _SettingsSection {
  final String title;
  final String? description;
  final List<_SettingItem> items;

  const _SettingsSection({required this.title, required this.items, this.description});
}

enum _SettingKind {
  layoutAuto,
  layoutMobile,
  layoutTv,
  backgroundPoster,
  cachePlayback,
  manualRotate,
  drmMode,
  tvGrid,
  sourceManager,
  downloadNotice,
  reset,
}

enum _SettingItemStyle { radio, tile }

class _SettingItem {
  final _SettingKind kind;
  final _SettingItemStyle style;
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool active;
  final bool danger;
  final bool? switchValue;
  final bool showGridBar;

  const _SettingItem._({
    required this.kind,
    required this.style,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.active = false,
    this.danger = false,
    this.switchValue,
    this.showGridBar = false,
  });

  factory _SettingItem.radio({required _SettingKind kind, required String title, required bool active}) {
    return _SettingItem._(
      kind: kind,
      style: _SettingItemStyle.radio,
      icon: active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
      title: title,
      subtitle: '',
      value: active ? 'AKTIF' : '',
      active: active,
    );
  }

  factory _SettingItem.tile({
    required _SettingKind kind,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    bool danger = false,
    bool? switchValue,
    bool showGridBar = false,
  }) {
    return _SettingItem._(
      kind: kind,
      style: _SettingItemStyle.tile,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      danger: danger,
      switchValue: switchValue,
      showGridBar: showGridBar,
    );
  }
}
