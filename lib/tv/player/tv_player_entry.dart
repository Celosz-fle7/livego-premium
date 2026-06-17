import 'package:flutter/material.dart';

import '../../models/content_item.dart';
import '../screens/tv_basic_player_screen.dart';
import 'explorer3/tv_player_explorer3_screen.dart';
import 'tv_player_engine.dart';

class TvPlayerEntry {
  const TvPlayerEntry._();

  static Future<void> open(
    BuildContext context, {
    required ContentItem item,
    int? episode,
    PlayerEngineType? engine,
  }) {
    final selected = TvPlayerEngineConfig.selectedEngine(override: engine);
    TvPlayerDebugLog.event(
      'player_engine_selected',
      item: item,
      episode: episode,
      engine: selected.wireName,
      reason: selected == PlayerEngineType.nativeExo
          ? 'manual_native_override'
          : (engine == null ? 'default_flutter' : 'explicit_override'),
    );
    return Navigator.of(context).push(_routeFor(item: item, episode: episode, engine: selected));
  }

  static Future<void> replaceWithNativeExo(
    BuildContext context, {
    required ContentItem item,
    int? episode,
    String reason = 'flutter_failed',
  }) {
    TvPlayerDebugLog.event(
      'player_engine_fallback',
      item: item,
      episode: episode,
      engine: PlayerEngineType.nativeExo.wireName,
      reason: reason,
    );
    return Navigator.of(context).pushReplacement(
      _routeFor(item: item, episode: episode, engine: PlayerEngineType.nativeExo),
    );
  }

  static PageRouteBuilder<void> _routeFor({
    required ContentItem item,
    required int? episode,
    required PlayerEngineType engine,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => ColoredBox(
        color: Colors.black,
        child: _screenFor(item: item, episode: episode, engine: engine),
      ),
      transitionsBuilder: (_, __, ___, child) => ColoredBox(color: Colors.black, child: child),
    );
  }

  static Widget _screenFor({
    required ContentItem item,
    required int? episode,
    required PlayerEngineType engine,
  }) {
    switch (engine) {
      case PlayerEngineType.legacyHybrid:
        return TvBasicPlayerScreen(
          item: item,
          episode: episode,
          onFallbackToNative: (context, reason) => replaceWithNativeExo(
            context,
            item: item,
            episode: episode,
            reason: reason,
          ),
        );
      case PlayerEngineType.flutterFallback:
        return TvPlayerExplorer3Screen(
          item: item,
          episode: episode,
          preferNativeSurface: false,
          onFallbackToNative: (context, reason) => replaceWithNativeExo(
            context,
            item: item,
            episode: episode,
            reason: reason,
          ),
        );
      case PlayerEngineType.nativeExo:
        return TvPlayerExplorer3Screen(item: item, episode: episode, preferNativeSurface: true);
    }
  }
}
