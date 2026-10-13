import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/livego_settings.dart';

class PlayerPreferences {
  static const _qualityKey = 'player.quality';
  static const _subtitleEnabledKey = 'player.subtitle.enabled';
  static const _subtitleLanguageKey = 'player.subtitle.language';
  static const _audioTrackKey = 'player.audio.track';
  static const _speedKey = 'player.speed';
  static const _fitCoverKey = 'player.fit.cover';

  /// Preferensi per provider: {slug: {quality, subtitleEnabled, subtitleLanguage}}.
  /// Dipakai saat user atur kualitas/subtitle sambil nonton provider X ->
  /// tersimpan khusus X, tidak mengganggu provider lain.
  /// Provider yang belum pernah diatur -> fallback ke nilai global.
  static const _byProviderKey = 'player.preferences.byProvider';
  static final Map<String, Map<String, dynamic>> _byProvider = {};

  /// Default standar instalasi LiveGo:
  /// - TV: 360p (standar pasar TV box low-end, respon cepat & stabil)
  /// - Mobile / HP: 480p
  static String get defaultInitialQuality =>
      LiveGoSettings.runtimeLockedToTv ? '360p' : '480p';

  static String quality = '480p';
  static bool subtitleEnabled = true;
  static String subtitleLanguage = 'Auto';
  static String audioTrack = 'Source';
  static double speed = 1.0;
  static bool fitCover = false;

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final savedQuality = prefs.getString(_qualityKey);
    quality = (savedQuality != null && savedQuality.isNotEmpty)
        ? savedQuality
        : defaultInitialQuality;
    subtitleEnabled = prefs.getBool(_subtitleEnabledKey) ?? subtitleEnabled;
    subtitleLanguage = prefs.getString(_subtitleLanguageKey) ?? subtitleLanguage;
    audioTrack = prefs.getString(_audioTrackKey) ?? audioTrack;
    speed = prefs.getDouble(_speedKey) ?? speed;
    fitCover = prefs.getBool(_fitCoverKey) ?? fitCover;
    final rawByProvider = prefs.getString(_byProviderKey);
    if (rawByProvider != null && rawByProvider.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawByProvider);
        if (decoded is Map) {
          _byProvider.clear();
          for (final entry in decoded.entries) {
            final v = entry.value;
            if (v is Map) {
              _byProvider['${entry.key}'] = Map<String, dynamic>.from(v);
            }
          }
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  // --- Preferensi per provider (override nilai global) ---

  static String qualityFor(String slug) {
    final v = _byProvider[slug.trim().toLowerCase()]?['quality'];
    return (v is String && v.isNotEmpty) ? v : quality;
  }

  static Future<void> setQualityFor(String slug, String value) async {
    (_byProvider[slug.trim().toLowerCase()] ??= {})['quality'] = value;
    await _saveByProvider();
  }

  static bool subtitleEnabledFor(String slug) {
    final v = _byProvider[slug.trim().toLowerCase()]?['subtitleEnabled'];
    return v is bool ? v : subtitleEnabled;
  }

  static String subtitleLanguageFor(String slug) {
    final v = _byProvider[slug.trim().toLowerCase()]?['subtitleLanguage'];
    return (v is String && v.isNotEmpty) ? v : subtitleLanguage;
  }

  static Future<void> setSubtitleFor(
    String slug, {
    required bool enabled,
    String? language,
  }) async {
    final m = _byProvider[slug.trim().toLowerCase()] ??= {};
    m['subtitleEnabled'] = enabled;
    if (language != null && language.isNotEmpty) {
      m['subtitleLanguage'] = language;
    }
    await _saveByProvider();
  }

  static Future<void> _saveByProvider() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_byProviderKey, jsonEncode(_byProvider));
  }

  static Future<void> setQuality(String value) async {
    quality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qualityKey, value);
    LiveGoSettings.quality = value;
  }

  static Future<void> setSubtitle({required bool enabled, String? language}) async {
    subtitleEnabled = enabled;
    if (language != null && language.isNotEmpty) subtitleLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subtitleEnabledKey, subtitleEnabled);
    await prefs.setString(_subtitleLanguageKey, subtitleLanguage);
  }

  static Future<void> setAudioTrack(String value) async {
    audioTrack = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioTrackKey, value);
  }

  static Future<void> setSpeed(double value) async {
    speed = value.clamp(0.5, 2.0).toDouble();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speedKey, speed);
  }

  static Future<void> setFitCover(bool value) async {
    fitCover = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fitCoverKey, value);
  }
}
