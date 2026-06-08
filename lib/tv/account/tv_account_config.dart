import '../layout/tv_safe_zone.dart';

/// Account screen constants.
///
/// Keep Account layout, guard timing, and helper text outside the screen so TV
/// tuning does not touch BACK/focus/action flow.
class TvAccountConfig {
  const TvAccountConfig._();

  static const int backGuardMs = 420;
  static const int selectGuardMs = 300;
  static const int visibleMenuWithoutScroll = 4;

  static const double topPadding = TvSafeZone.accountTop;
  static const double horizontalPadding = TvSafeZone.accountSide;
  static const double bottomPadding = TvSafeZone.bottomReach;
  static const double headerHeight = 92;
  static const double afterHeader = 12;
  static const double rowHeight = 80;
  static const double rowGap = 8;
  static const double footerGap = 10;
  static const double footerHeight = 38;
  static const double comfortTop = TvSafeZone.listTop;
  static const double comfortBottom = TvSafeZone.listBottom;
  static const double cacheExtent = 420;

  static const Duration snackDuration = Duration(seconds: 2);

  static const String footerHelp =
      '↓/→ masuk menu • OK buka • ←/BACK ke Navbar Akun';
  static const String aboutMessage =
      'LiveGo Premium TV • data sinkron dengan mode HP';
  static const String updateMessage =
      'Update mengikuti build GitHub Actions terbaru.';
}
