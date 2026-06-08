import '../layout/tv_safe_zone.dart';

/// Search screen constants.
///
/// Keep keyboard/search-result tuning outside the screen so final TV polishing
/// does not touch search provider, API, or route flow.
class TvSearchConfig {
  const TvSearchConfig._();

  static const int searchSubmitGuardMs = 650;
  static const double inputFocusAlignment = 0.12;
  static const double resultTileWidthTarget = 168;
  static const int minColumns = 4;
  static const int maxColumns = 7;

  static const double headerToInputGap = 14;
  static const double inputBorderPadding = 3;
  static const double inputBorderRadius = 22;
  static const double inputFieldRadius = 19;
  static const double keyboardGap = 10;
  static const double afterKeyboardGap = 16;
  static const double loadingTopPadding = 70;
  static const double loadingTextGap = 12;
  static const double resultHelpGap = 12;
  static const double posterMainAxisExtent = 224;

  static const double gridTopMargin = TvSafeZone.listTop;
  static const double gridBottomMargin = TvSafeZone.gridBottom;
  static const double listTopMargin = TvSafeZone.listTop;
  static const double listBottomMargin = TvSafeZone.listBottom;
  static const double cacheExtent = TvSafeZone.cacheExtent;
  static const double resultBottomPadding = TvSafeZone.bottomReach;

  static const String title = 'Pencarian';
  static const String subtitle = 'Cari semua sumber aktif LiveGo.';
  static const String hint = 'Cari drama, CEO, cinta, balas dendam...';
  static const String loadingText = 'Mencari... remote tetap aktif';
  static const String emptyTitle = 'Cari dari source aktif LiveGo';
  static const String emptySubtitle = 'Ketik kata kunci lalu tekan Enter/Search.';
  static const String noResultTitle = 'Tidak ada hasil';
  static const String retrySubtitle = 'OK coba lagi • UP ke input • LEFT ke navbar';
  static const String errorTitle = 'Pencarian gagal dimuat';
  static const String resultHelp = '↑ input • OK detail • ← navbar • Back input';

  static int columnsFor(double width) {
    return (width / resultTileWidthTarget).floor().clamp(minColumns, maxColumns).toInt();
  }
}
