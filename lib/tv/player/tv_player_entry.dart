import 'package:flutter/material.dart';

import '../../models/content_item.dart';
import 'explorer3/tv_player_explorer3_screen.dart';
import 'tv_player_engine.dart';

class TvPlayerEntry {
  const TvPlayerEntry._();

  static Future<void> open(
    BuildContext context, {
    required ContentItem item,
    int? episode,
  }) {
    const selected = PlayerEngineType.nativeExo;
    TvPlayerDebugLog.event(
      'player_engine_selected',
      item: item,
      episode: episode,
      engine: selected.wireName,
      reason: 'native_only',
    );
    return Navigator.of(context).push(_routeFor(item: item, episode: episode));
  }

  static PageRouteBuilder<void> _routeFor({
    required ContentItem item,
    required int? episode,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => ColoredBox(
        color: Colors.black,
        child: TvPlayerExplorer3Screen(item: item, episode: episode),
      ),
      transitionsBuilder: (_, __, ___, child) => ColoredBox(color: Colors.black, child: child),
    );
  }
}
