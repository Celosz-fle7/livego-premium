import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// Small in-memory cache for Android TV runtime/UI performance.
///
/// This is NOT API cache and NOT security cache.
/// Purpose:
/// - reduce repeated lightweight UI computation
/// - keep remote/focus responsive
/// - avoid turning screen widgets into cache containers
/// - keep cache payload compact with a small binary codec
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
  static const int _maxStringBytes = 2048;
  static const int _maxIntListItems = 64;

  static final LinkedHashMap<String, _TvRuntimeCacheEntry> _entries =
      LinkedHashMap<String, _TvRuntimeCacheEntry>();

  static Object? getObject(String key) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;
    final entry = _entries.remove(cleanKey);
    if (entry == null) return null;
    if (entry.isExpired) return null;

    final value = _TvRuntimeBinaryCodec.decode(entry.payload);
    if (value == null) return null;

    // Move to the end so the oldest unused item is evicted first.
    _entries[cleanKey] = entry.touch();
    return value;
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

    final payload = _TvRuntimeBinaryCodec.encode(
      value,
      maxStringBytes: _maxStringBytes,
      maxIntListItems: _maxIntListItems,
    );
    if (payload == null) return;

    _entries.remove(cleanKey);
    final now = DateTime.now();
    _entries[cleanKey] = _TvRuntimeCacheEntry(
      payload: payload,
      expiresAt: now.add(ttl),
      touchedAt: now,
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
    setObject(key, value, ttl: ttl);
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

  static int get payloadBytes {
    clearExpired();
    var total = 0;
    for (final entry in _entries.values) {
      total += entry.payload.lengthInBytes;
    }
    return total;
  }

  static String screenKey(String screen, String name) {
    return 'screen:${screen.trim()}:${name.trim()}';
  }

  static String playerKey(String itemId, Object episode, String name) {
    return 'player:${itemId.trim()}:$episode:${name.trim()}';
  }

  static void _trim() {
    clearExpired();
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _TvRuntimeCacheEntry {
  final Uint8List payload;
  final DateTime expiresAt;
  final DateTime touchedAt;

  const _TvRuntimeCacheEntry({
    required this.payload,
    required this.expiresAt,
    required this.touchedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  _TvRuntimeCacheEntry touch() {
    return _TvRuntimeCacheEntry(
      payload: payload,
      expiresAt: expiresAt,
      touchedAt: DateTime.now(),
    );
  }
}

class _TvRuntimeBinaryCodec {
  static const int _typeInt = 1;
  static const int _typeString = 2;
  static const int _typeBool = 3;
  static const int _typeIntList = 4;

  static Uint8List? encode(
    Object value, {
    required int maxStringBytes,
    required int maxIntListItems,
  }) {
    if (value is int) {
      final bytes = Uint8List(9);
      bytes[0] = _typeInt;
      ByteData.view(bytes.buffer).setInt64(1, value, Endian.little);
      return bytes;
    }

    if (value is bool) {
      return Uint8List.fromList(<int>[_typeBool, value ? 1 : 0]);
    }

    if (value is String) {
      final encoded = utf8.encode(value);
      if (encoded.length > maxStringBytes) return null;
      final bytes = Uint8List(1 + encoded.length);
      bytes[0] = _typeString;
      bytes.setRange(1, bytes.length, encoded);
      return bytes;
    }

    if (value is List<int>) {
      final rows = value.take(maxIntListItems).toList(growable: false);
      final bytes = Uint8List(3 + rows.length * 4);
      final data = ByteData.view(bytes.buffer);
      bytes[0] = _typeIntList;
      data.setUint16(1, rows.length, Endian.little);
      for (var i = 0; i < rows.length; i++) {
        final safe = rows[i].clamp(-2147483648, 2147483647).toInt();
        data.setInt32(3 + i * 4, safe, Endian.little);
      }
      return bytes;
    }

    return null;
  }

  static Object? decode(Uint8List payload) {
    if (payload.isEmpty) return null;
    final data = ByteData.view(payload.buffer, payload.offsetInBytes, payload.lengthInBytes);

    switch (payload[0]) {
      case _typeInt:
        if (payload.lengthInBytes < 9) return null;
        return data.getInt64(1, Endian.little);

      case _typeBool:
        if (payload.lengthInBytes < 2) return null;
        return payload[1] == 1;

      case _typeString:
        if (payload.lengthInBytes < 1) return '';
        return utf8.decode(payload.sublist(1), allowMalformed: true);

      case _typeIntList:
        if (payload.lengthInBytes < 3) return const <int>[];
        final count = data.getUint16(1, Endian.little);
        final rows = <int>[];
        final maxCount = ((payload.lengthInBytes - 3) ~/ 4).clamp(0, count).toInt();
        for (var i = 0; i < maxCount; i++) {
          rows.add(data.getInt32(3 + i * 4, Endian.little));
        }
        return List<int>.unmodifiable(rows);
    }

    return null;
  }
}
