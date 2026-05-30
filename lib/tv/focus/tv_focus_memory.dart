import 'package:flutter/widgets.dart';
import 'tv_focus_zone.dart';

class TvFocusMemory {
  int lastNavIndex = 0;
  int lastPlatformIndex = 0;
  int lastCategoryIndex = 0;
  int lastGridIndex = 0;
  TvFocusZone lastRightZone = TvFocusZone.grid;
  FocusNode? lastRightFocus;

  void rememberNav(int index) {
    lastNavIndex = index;
  }

  void rememberRight(
    FocusNode node,
    TvFocusZone zone, {
    int? platformIndex,
    int? categoryIndex,
    int? gridIndex,
  }) {
    lastRightFocus = node;
    lastRightZone = zone;
    if (platformIndex != null) lastPlatformIndex = platformIndex;
    if (categoryIndex != null) lastCategoryIndex = categoryIndex;
    if (gridIndex != null) lastGridIndex = gridIndex;
  }

  void clearRightNode() {
    lastRightFocus = null;
  }
}
