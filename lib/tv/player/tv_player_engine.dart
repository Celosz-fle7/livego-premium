import 'package:flutter/foundation.dart';

import '../../core/livego_settings.dart';
import '../../models/content_item.dart';

/// TV player engine selection contract.
///
/// The default must remain [PlayerEngineType.nativeExo]. Legacy/hybrid is a
/// non-default internal fallback engine that can be enabled with:
/// `--dart-define=LIVEGO_TV_PLAYER_ENGINE=legacyHybrid`.
enum PlayerEngineType {
  nativeExo,
  legacyHybrid,
  flutterFallback,
}

extension PlayerEngineTypeLabel on PlayerEngineType {
  String get wireName {
    switch (this) {
      case PlayerEngineType.nativeExo:
        return 'nativeExo';
      case PlayerEngineType.legacyHybrid:
        return 'legacyHybrid';
      case PlayerEngineType.flutterFallback:
        return 'flutterFallback';
    }
  }
}

class TvPlayerEngineConfig {
  const TvPlayerEngineConfig._();

  static const String _defineEngine = String.fromEnvironment(
    'LIVEGO_TV_PLAYER_ENGINE',
    defaultValue: '',
  );

  static PlayerEngineType get defaultEngine => PlayerEngineType.nativeExo;

  static PlayerEngineType selectedEngine({PlayerEngineType? override}) {
    return override ?? _fromName(LiveGoSettings.tvPlayerEngineOverride) ?? _fromName(_defineEngine) ?? defaultEngine;
  }

  static bool get legacyEnabled => selectedEngine() == PlayerEngineType.legacyHybrid;

  static PlayerEngineType? _fromName(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'nativeexo':
      case 'native':
      case 'exo':
      case 'exoplayer':
        return PlayerEngineType.nativeExo;
      case 'legacyhybrid':
      case 'legacy':
      case 'hybrid':
        return PlayerEngineType.legacyHybrid;
      case 'flutterfallback':
      case 'flutter':
      case 'fallback':
        return PlayerEngineType.flutterFallback;
      default:
        return null;
    }
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
