import 'dart:collection';

/// Small in-memory cache for Android TV runtime/UI performance.
///
/// This is NOT API cache and NOT security cache.
/// Purpose:
/// - reduce repeated lightweight UI computation
/// - keep remote/focus responsive
/// - avoid turning screen widgets into cache containers
///
/// Rules:
/// - no BuildContext
/// - no FocusNode
/// - no VideoPlayerController
/// - no Timer
/// - no stream/controller objects
/// - no large image bytes
/// - no provider/listener/rebuild trigger
class TvRuntimeCache {
  TvRuntimeCache._();

  static const int _maxEntries = 96;

  static final LinkedHashMap<String, _TvRuntimeCacheEntry> _entries =
      LinkedHashMap<String, _TvRuntimeCacheEntry>();

  static Object? getObject(String key) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;
    final entry = _entries.remove(cleanKey);
    if (entry == null) return null;
    if (entry.isExpired) return null;

    // Move to the end so the oldest unused item is evicted first.
    _entries[cleanKey] = entry.touch();
    return entry.value;
  }

  static int? getInt(String key) {
    final value = getObject(key);
    return value is int ? value : null;
  }

  static String? getString(String key) {
    final value = getObject(key);
    return value is String ? value : null;
  }

  static bool? getBool(String key) {
    final value = getObject(key);
    return value is bool ? value : null;
  }

  static List<int>? getIntList(String key) {
    final value = getObject(key);
    if (value is! List<int>) return null;
    return List<int>.unmodifiable(value);
  }

  static void setObject(
    String key,
    Object value, {
    Duration ttl = const Duration(minutes: 20),
  }) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return;
    if (!_isAllowedValue(value)) return;

    _entries.remove(cleanKey);
    _entries[cleanKey] = _TvRuntimeCacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
      touchedAt: DateTime.now(),
    );
    _trim();
  }

  static void setInt(String key, int value, {Duration ttl = const Duration(hours: 2)}) {
    setObject(key, value, ttl: ttl);
  }

  static void setString(String key, String value, {Duration ttl = const Duration(hours: 2)}) {
    setObject(key, value, ttl: ttl);
  }

  static void setBool(String key, bool value, {Duration ttl = const Duration(hours: 2)}) {
    setObject(key, value, ttl: ttl);
  }

  static void setIntList(
    String key,
    List<int> value, {
    Duration ttl = const Duration(minutes: 20),
  }) {
    setObject(key, List<int>.unmodifiable(value.take(64)), ttl: ttl);
  }

  static void remove(String key) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return;
    _entries.remove(cleanKey);
  }

  static void clearPrefix(String prefix) {
    final cleanPrefix = prefix.trim();
    if (cleanPrefix.isEmpty) return;
    final keys = _entries.keys.where((key) => key.startsWith(cleanPrefix)).toList(growable: false);
    for (final key in keys) {
      _entries.remove(key);
    }
  }

  static void clearPlayerSession() {
    clearPrefix('player:');
  }

  static void clearScreenSession(String screenName) {
    final clean = screenName.trim();
    if (clean.isEmpty) return;
    clearPrefix('screen:$clean:');
  }

  static void clearExpired() {
    final keys = _entries.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in keys) {
      _entries.remove(key);
    }
  }

  static void clearAll() {
    _entries.clear();
  }

  static int get size {
    clearExpired();
    return _entries.length;
  }

  static String screenKey(String screen, String name) {
    return 'screen:${screen.trim()}:${name.trim()}';
  }

  static String playerKey(String itemId, Object episode, String name) {
    return 'player:${itemId.trim()}:$episode:${name.trim()}';
  }

  static bool _isAllowedValue(Object value) {
    if (value is int || value is String || value is bool) return true;
    if (value is List<int>) return value.length <= 64;
    return false;
  }

  static void _trim() {
    clearExpired();
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _TvRuntimeCacheEntry {
  final Object value;
  final DateTime expiresAt;
  final DateTime touchedAt;

  const _TvRuntimeCacheEntry({
    required this.value,
    required this.expiresAt,
    required this.touchedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  _TvRuntimeCacheEntry touch() {
    return _TvRuntimeCacheEntry(
      value: value,
      expiresAt: expiresAt,
      touchedAt: DateTime.now(),
    );
  }
}
