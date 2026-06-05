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
  static const double smallTail = 32;
  static const double cacheExtent = 420;

  static const EdgeInsets account = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);
  static const EdgeInsets settings = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);
  static const EdgeInsets source = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);
  static const EdgeInsets search = EdgeInsets.fromLTRB(40, 24, 48, bottomReach);
  static const EdgeInsets library = EdgeInsets.fromLTRB(40, 24, 48, bottomReach);
  static const EdgeInsets downloads = EdgeInsets.fromLTRB(48, 24, 48, bottomReach);

  static const double listTop = 96;
  static const double listBottom = 160;
  static const double gridTop = 112;
  static const double gridBottom = 170;

  static const double accountRevealAlignment = 0.36;
  static const double listRevealAlignment = 0.42;
}
