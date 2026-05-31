import 'package:flutter/widgets.dart';

import 'tv_focus_zone.dart';

class TvFocusMemory {
  int lastNavIndex = 0;
  int lastPlatformIndex = 0;
  int lastCategoryIndex = 0;
  int lastGridIndex = 0;
  int lastSettingsIndex = 0;
  int lastAccountIndex = 0;
  TvFocusZone lastRightZone = TvFocusZone.banner;
  FocusNode? lastRightFocus;

  void rememberRight(
    FocusNode node,
    TvFocusZone zone, {
    int? platformIndex,
    int? categoryIndex,
    int? gridIndex,
    int? settingsIndex,
    int? accountIndex,
  }) {
    lastRightFocus = node;
    lastRightZone = zone;
    if (platformIndex != null) lastPlatformIndex = platformIndex;
    if (categoryIndex != null) lastCategoryIndex = categoryIndex;
    if (gridIndex != null) lastGridIndex = gridIndex;
    if (settingsIndex != null) lastSettingsIndex = settingsIndex;
    if (accountIndex != null) lastAccountIndex = accountIndex;
  }

  void clearRightNode() {
    lastRightFocus = null;
  }
}
