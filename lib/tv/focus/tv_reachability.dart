import 'package:flutter/widgets.dart';

/// Shared TV viewport/reachability numbers.
///
/// Keep these values centralized so focus margins and scroll padding do not
/// drift apart per screen. A focused item can only be fully revealed when the
/// scrollable has more bottom padding/spacer than the reveal bottom margin.
class TvReachability {
  const TvReachability._();

  // Margins used by focus helpers.
  static const double zoneTopMargin = 32;
  static const double listTopMargin = 32;
  static const double listBottomMargin = 72;
  static const double gridTopMargin = 56;
  static const double gridBottomMargin = 96;

  // Minimum bottom reach for scrollables. Must stay >= the largest bottomMargin.
  static const double homeBottomPadding = 160;
  static const double contentBottomPadding = 160;
  static const double managerBottomPadding = 160;
  static const double trailingSpacer = 96;

  static const EdgeInsets homePadding = EdgeInsets.fromLTRB(28, 28, 38, homeBottomPadding);
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(32, 32, 44, contentBottomPadding);
  static const EdgeInsets accountPadding = EdgeInsets.fromLTRB(48, 24, 48, contentBottomPadding);
  static const EdgeInsets managerPadding = EdgeInsets.fromLTRB(48, 24, 48, managerBottomPadding);

  static const SizedBox tailSpacer = SizedBox(height: trailingSpacer);
}
