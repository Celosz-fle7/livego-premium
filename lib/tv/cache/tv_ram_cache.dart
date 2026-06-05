/// Small RAM-only cache for TV UI state.
///
/// This is not API cache, not image cache, not video cache.
/// It exists only to keep active TV UI sessions responsive while the app is alive.
///
/// Rules:
/// - RAM only; cleared when app process dies.
/// - Small max entry count.
/// - TTL-based.
/// - No video stream URLs.
/// - Home/Search may use it, but Home must not become a cache warehouse.
class TvRamCache {
  TvRamCache._();

  static final TvRamCache instance = TvRamCache._();

  static const int maxEntries = 24;
  static const Duration homeTtl = Duration(minutes: 20);
  static const Duration searchTtl = Duration(minutes: 10);

  final Map<String, _TvRamCacheEntry<Object>> _store = <String, _TvRamCacheEntry<Object>>{};

  T? read<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.expired) {
      _store.remove(key);
      return null;
    }
    final value = entry.value;
    if (value is T) return value;
    return null;
  }

  void write<T extends Object>(String key, T value, {required Duration ttl}) {
    if (key.trim().isEmpty || ttl <= Duration.zero) return;
    clearExpired();
    _store[key] = _TvRamCacheEntry<Object>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
      touchedAt: DateTime.now(),
    );
    _trim();
  }

  void remove(String key) {
    _store.remove(key);
  }

  void clearExpired() {
    final now = DateTime.now();
    _store.removeWhere((_, entry) => entry.expiresAt.isBefore(now));
  }

  void clearAll() {
    _store.clear();
  }

  static String key(String scope, List<Object?> parts) {
    final cleanScope = _safe(scope);
    final suffix = parts
        .where((part) => part != null && '$part'.trim().isNotEmpty)
        .map((part) => _safe('$part'))
        .join(':');
    return suffix.isEmpty ? cleanScope : '$cleanScope:$suffix';
  }

  static String _safe(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '_');
  }

  void _trim() {
    if (_store.length <= maxEntries) return;
    final entries = _store.entries.toList()
      ..sort((a, b) => a.value.touchedAt.compareTo(b.value.touchedAt));
    final removeCount = _store.length - maxEntries;
    for (final entry in entries.take(removeCount)) {
      _store.remove(entry.key);
    }
  }
}

class _TvRamCacheEntry<T extends Object> {
  final T value;
  final DateTime expiresAt;
  final DateTime touchedAt;

  const _TvRamCacheEntry({
    required this.value,
    required this.expiresAt,
    required this.touchedAt,
  });

  bool get expired => DateTime.now().isAfter(expiresAt);
}
