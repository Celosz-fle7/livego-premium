import 'package:flutter/widgets.dart';
import 'tv_focus_memory.dart';
import 'tv_focus_zone.dart';

class TvFocusEngine {
  final TvFocusMemory memory;

  TvFocusEngine({required this.memory});

  void rememberRight(
    FocusNode node,
    TvFocusZone zone, {
    int? platformIndex,
    int? categoryIndex,
    int? gridIndex,
  }) {
    memory.rememberRight(
      node,
      zone,
      platformIndex: platformIndex,
      categoryIndex: categoryIndex,
      gridIndex: gridIndex,
    );
  }

  void clearRightNode() => memory.clearRightNode();

  bool restoreLastRight({required void Function(FocusNode node, {double alignment}) focus}) {
    final node = memory.lastRightFocus;
    if (node == null || !node.canRequestFocus || node.context == null) return false;
    focus(node, alignment: memory.lastRightZone == TvFocusZone.grid ? 0.35 : 0.15);
    return true;
  }

  int safeIndex(int value, int length) {
    if (length <= 0) return 0;
    return value.clamp(0, length - 1);
  }
}
