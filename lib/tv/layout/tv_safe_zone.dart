import 'package:flutter/widgets.dart';

/// Central TV layout contract.
///
/// SCREEN SAFE MARGIN = safe distance from TV screen edges.
/// ZONE MARGIN        = comfortable reveal margin for focused rows/grids.
/// BOTTOM REACH       = enough tail space so the last item can scroll upward.
///
/// Home intentionally stays on its current stable layout until final pass.
class TvSafeZone {
  const TvSafeZone._();

  static const double bottomReach = 220;
  static const double homeGridBottomReach = 190;
  // Header Home sticky = 128 (Platform 44 + gap 3 + Kategori 44 + gap 3 +
  // Search 32 + padding bawah 2). Offset grid entry = header + 135.
  static const double homeGridEntryOffset = 263;
  static const double accountTop = 24;
  static const double accountSide = 48;
  static const double settingsTop = 24;
  static const double settingsSide = 48;
  static const double sourceTop = 24;
  static const double sourceSide = 48;
  static const double searchTop = 24;
  static const double searchSideLeft = 40;
  static const double searchSideRight = 48;
  static const double smallTail = 32;
  static const double cacheExtent = 420;

  static const EdgeInsets account = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);
  static const EdgeInsets settings = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);
  static const EdgeInsets source = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);
  static const EdgeInsets search = EdgeInsets.fromLTRB(40, 24, 48, bottomReach);
  static const EdgeInsets library = EdgeInsets.fromLTRB(40, 24, 48, bottomReach);
  static const EdgeInsets downloads = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);
  // Top Home dikurangi 28 -> 20 -> 16 untuk memberi ruang search bar di bawah
  // chip Kategori tanpa membuat layout bertumpuk.
  static const EdgeInsets home = EdgeInsets.fromLTRB(32, 16, 44, bottomReach);

  static const double listTop = 96;
  static const double listBottom = 160;
  static const double gridTop = 112;
  static const double gridBottom = 170;

  static const double accountRevealAlignment = 0.36;
  static const double listRevealAlignment = 0.42;
}
