import 'package:flutter/foundation.dart';

import '../../models/content_item.dart';

/// TV player engine selection contract.
///
/// TV player is 100% Native ExoPlayer (MethodChannel 'livego/native_surface_player').
/// There is no Flutter fallback engine.
enum PlayerEngineType {
  nativeExo,
}

extension PlayerEngineTypeLabel on PlayerEngineType {
  String get wireName {
    switch (this) {
      case PlayerEngineType.nativeExo:
        return 'nativeExo';
    }
  }
}

class TvPlayerEngineConfig {
  const TvPlayerEngineConfig._();

  static PlayerEngineType get defaultEngine => PlayerEngineType.nativeExo;

  static PlayerEngineType selectedEngine({PlayerEngineType? override, bool isCenc = false}) {
    return PlayerEngineType.nativeExo;
  }
}

class TvPlayerDebugLog {
  const TvPlayerDebugLog._();

  static void event(
    String event, {
    ContentItem? item,
    int? episode,
    String? engine,
    String? reason,
    String? host,
    String? tail,
    Object? error,
  }) {
    final parts = <String>['LIVEGO_PLAYER event=$event'];
    if (engine != null && engine.trim().isNotEmpty) parts.add('engine=${engine.trim()}');
    if (item != null) {
      parts.add('platform=${item.platformSlug}');
      parts.add('content=${_safeToken(item.id)}');
    }
    if (episode != null) parts.add('episode=$episode');
    if (reason != null && reason.trim().isNotEmpty) parts.add('reason=${reason.trim()}');
    if (host != null && host.trim().isNotEmpty) parts.add('host=${host.trim()}');
    if (tail != null && tail.trim().isNotEmpty) parts.add('tail=${_safeTail(tail)}');
    if (error != null) parts.add('error=${_safeToken('$error')}');
    debugPrint(parts.join(' '));
  }

  static String _safeToken(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), '_');
    if (clean.length <= 80) return clean;
    return clean.substring(clean.length - 80);
  }

  static String _safeTail(String value) {
    final clean = value.trim();
    if (clean.length <= 32) return clean;
    return clean.substring(clean.length - 32);
  }
}
