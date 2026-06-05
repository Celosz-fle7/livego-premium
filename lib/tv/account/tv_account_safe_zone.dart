import 'package:flutter/widgets.dart';

/// Account-specific TV layout contract.
///
/// SCREEN SAFE MARGIN = safe distance from TV screen edges.
/// ZONE MARGIN        = comfortable reveal margin for focused rows.
/// BOTTOM REACH       = enough tail space so the last item can scroll upward.
class TvAccountSafeZone {
  const TvAccountSafeZone._();

  static const double bottomReach = 220;

  static const EdgeInsets screenMargin = EdgeInsets.fromLTRB(
    48,
    24,
    48,
    bottomReach,
  );

  static const double focusTopMargin = 96;
  static const double focusBottomMargin = 160;

  static const double cacheExtent = 420;
}
