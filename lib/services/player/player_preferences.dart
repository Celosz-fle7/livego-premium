import 'package:shared_preferences/shared_preferences.dart';

import '../../core/livego_settings.dart';

class PlayerPreferences {
  static const _qualityKey = 'player.quality';
  static const _subtitleEnabledKey = 'player.subtitle.enabled';
  static const _subtitleLanguageKey = 'player.subtitle.language';
  static const _audioTrackKey = 'player.audio.track';
  static const _speedKey = 'player.speed';
  static const _fitCoverKey = 'player.fit.cover';

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
    _loaded = true;
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
