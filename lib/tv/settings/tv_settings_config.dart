import '../layout/tv_safe_zone.dart';

/// Settings screen constants.
///
/// Keep layout, guard timing, helper text, and fixed option values outside the
/// screen so TV tuning does not touch BACK/focus/settings behavior.
class TvSettingsConfig {
  const TvSettingsConfig._();

  static const int backGuardMs = 420;
  static const double cacheExtent = 420;

  static const double topPadding = TvSafeZone.settingsTop;
  static const double horizontalPadding = TvSafeZone.settingsSide;
  static const double bottomPadding = TvSafeZone.bottomReach;
  static const double headerHeight = 96;
  static const double pillsHeight = 42;
  static const double sectionTitleHeight = 31;
  static const double sectionGap = 16;
  static const double cardVerticalPadding = 6;
  static const double descriptionHeight = 48;
  static const double radioRowHeight = 55;
  static const double tileRowHeight = 82;
  static const double gridRowHeight = 122;
  static const double footerHeight = 48;
  static const double comfortTop = TvSafeZone.listTop;
  static const double comfortBottom = TvSafeZone.listBottom;

  static const double headerToPillsGap = 12;
  static const double pillsToSectionsGap = 14;
  static const double sectionTitleGap = 10;
  static const double pillGap = 10;

  static const int resetTvGrid = 6;

  static const List<String> drmValues = <String>[
    'Auto',
    'Paksa L3',
    'Nonaktifkan Paksa L3',
  ];

  static const String footerSettingsHelp =
      'Remote: ↑↓ pilih item • OK/→ ubah nilai • ←/Back kembali';
  static const String footerNavHelp =
      'Remote: ↓/→ masuk pengaturan • ←/Back kembali';
}
