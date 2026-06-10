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
  static const double headerHeight = 90;
  static const double pillsHeight = 38;
  static const double sectionTitleHeight = 28;
  static const double sectionGap = 12;
  static const double cardVerticalPadding = 5;
  static const double descriptionHeight = 42;
  static const double radioRowHeight = 50;
  static const double tileRowHeight = 76;
  static const double footerHeight = 38;
  static const double comfortTop = TvSafeZone.listTop;
  static const double comfortBottom = TvSafeZone.listBottom;

  static const double headerToPillsGap = 10;
  static const double pillsToSectionsGap = 12;
  static const double sectionTitleGap = 8;
  static const double pillGap = 8;


  static const String footerSettingsHelp =
      '↑↓ pilih • OK/→ ubah • ←/BACK kembali';
  static const String footerNavHelp =
      '↓/→ masuk pengaturan • ←/BACK kembali';
}
