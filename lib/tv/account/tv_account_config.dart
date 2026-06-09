import '../layout/tv_safe_zone.dart';

/// Account screen constants.
///
/// Keep Account layout, guard timing, and helper text outside the screen so TV
/// tuning does not touch BACK/focus/action flow.
class TvAccountConfig {
  const TvAccountConfig._();

  static const int backGuardMs = 420;
  static const int selectGuardMs = 300;
  static const int visibleMenuRowsWithoutScroll = 3;

  static const double topPadding = TvSafeZone.accountTop;
  static const double horizontalPadding = TvSafeZone.accountSide;
  static const double bottomPadding = TvSafeZone.bottomReach + 72;
  static const double headerHeight = 84;
  static const double afterHeader = 14;
  static const int gridColumnCount = 2;
  static const double cardHeight = 94;
  static const double cardGap = 12;
  static const double footerGap = 14;
  static const double footerHeight = 38;
  static const double comfortTop = TvSafeZone.listTop;
  static const double comfortBottom = TvSafeZone.gridBottom;
  static const double cacheExtent = 520;

  static const Duration snackDuration = Duration(seconds: 2);

  static const String footerHelp =
      'D-pad pilih kartu • OK buka • ← dari kolom kiri / BACK ke Navbar Akun';
  static const String aboutMessage =
      'LiveGo Premium TV • data sinkron dengan mode HP';
}
