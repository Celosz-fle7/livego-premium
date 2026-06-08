import '../layout/tv_safe_zone.dart';

/// Source Manager constants and source-family rules.
///
/// Keep these values outside the screen so Dobda/Anichin separation and TV
/// reachability tuning do not require editing UI/key-handling code.
class TvSourceManagerConfig {
  const TvSourceManagerConfig._();

  static const String fallbackPlatform = 'dobda_freereels';
  static const int maxActivePlatforms = 6;
  static const int maxHomePlatforms = 6;
  static const int maxCategoriesPerPlatform = 6;
  static const int recommendedPriorityLimit = 50;
  static const int betaPriorityStart = 850;

  static const int backGuardMs = 420;

  static const double topPadding = TvSafeZone.sourceTop;
  static const double horizontalPadding = TvSafeZone.sourceSide;
  static const double bottomPadding = TvSafeZone.bottomReach;
  static const double headerHeight = 76;
  static const double afterHeader = 14;
  static const double panelPadding = 10;
  static const double groupHeaderHeight = 36;
  static const double rowHeight = 149;
  static const double footerHeight = 52;
  static const double comfortTop = TvSafeZone.listTop;
  static const double comfortBottom = TvSafeZone.listBottom;

  static const String sourceGroupTitle = 'LIVEGO SOURCE';
  static const String footerHelp =
      'OK ON/OFF platform • RIGHT kategori • OK kategori ON/OFF • BACK satu langkah';
  static const String subtitle =
      'Source LiveGo untuk Beranda TV. Kategori: Home dan LiveGo.';

  static const Map<String, int> sourceOrder = <String, int>{
    'dobda_freereels': 0,
    'dobda_goodshort': 1,
    'dobda_dramawave': 2,
    'dobda_reelshort': 3,
    'dobda_reelife': 4,
    'dobda_rapidtv': 5,
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
