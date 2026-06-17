import '../layout/tv_safe_zone.dart';

/// Source Manager constants and source-family rules.
///
/// Keep these values outside the screen so Nobuzero/Anichin separation and TV
/// reachability tuning do not require editing UI/key-handling code.
class TvSourceManagerConfig {
  const TvSourceManagerConfig._();

  static const String fallbackPlatform = 'nobuzero_freereels';
  static const int maxActivePlatforms = 999;
  static const int maxHomePlatforms = 999;
  static const int maxCategoriesPerPlatform = 6;
  static const int recommendedPriorityLimit = 50;
  static const int betaPriorityStart = 850;

  static const int backGuardMs = 420;

  static const double topPadding = TvSafeZone.sourceTop;
  static const double horizontalPadding = TvSafeZone.sourceSide;
  static const double bottomPadding = TvSafeZone.bottomReach;
  static const double headerHeight = 72;
  static const double afterHeader = 10;
  static const double panelPadding = 8;
  static const double groupHeaderHeight = 30;
  static const double rowHeight = 82;
  static const double categoryRowHeight = 138;
  static const double footerHeight = 38;
  static const double comfortTop = TvSafeZone.listTop;
  static const double comfortBottom = TvSafeZone.listBottom;

  static const String sourceGroupTitle = 'LIVEGO SOURCE';
  static const String footerHelp =
      'OK ON/OFF platform • BACK simpan atau batal';
  static const String subtitle =
      'Source Beranda TV. Pilih platform aktif. Kategori diatur dari shortcut Kategori Home.';

  static const Map<String, int> sourceOrder = <String, int>{
    'nobuzero_melolo': 0,
    'nobuzero_dramabox': 1,
    'nobuzero_moviebox': 2,
    'nobuzero_mydrama': 3,
    'nobuzero_netshort': 4,
    'nobuzero_shortmax': 5,
    'nobuzero_freereels': 6,
    'nobuzero_dramawave': 7,
  };

  static int sourcePriority(String slug) {
    return sourceOrder[slug] ?? 99;
  }

  static bool isRecommended(String slug) {
    return sourcePriority(slug) < recommendedPriorityLimit;
  }

  static bool isBeta(String slug) {
    return sourcePriority(slug) >= betaPriorityStart;
  }
}
