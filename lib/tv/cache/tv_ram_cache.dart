import '../../services/cache/livego_cache_observer.dart';

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
    if (entry == null) {
      LiveGoCacheObserver.log(
        key.startsWith('home:') ? 'home_cache_miss' : 'cache_miss',
        domain: key.startsWith('home:') ? 'home' : 'ram',
        key: key,
      );
      return null;
    }
    if (entry.expired) {
      _store.remove(key);
      LiveGoCacheObserver.log(
        key.startsWith('home:') ? 'home_cache_expired' : 'cache_expired',
        domain: key.startsWith('home:') ? 'home' : 'ram',
        key: key,
        expired: true,
      );
      return null;
    }
    final value = entry.value;
    if (value is T) {
      LiveGoCacheObserver.log(
        key.startsWith('home:') ? 'home_cache_hit' : 'cache_hit',
        domain: key.startsWith('home:') ? 'home' : 'ram',
        key: key,
      );
      return value as T;
    }
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
    LiveGoCacheObserver.log(
      key.startsWith('home:') ? 'home_cache_saved' : 'cache_saved',
      domain: key.startsWith('home:') ? 'home' : 'ram',
      key: key,
      ttl: ttl,
    );
    _trim();
  }

  void remove(String key) {
    _store.remove(key);
  }

  void clearExpired() {
    final now = DateTime.now();
    var removed = 0;
    _store.removeWhere((_, entry) {
      final expired = entry.expiresAt.isBefore(now);
      if (expired) removed++;
      return expired;
    });
    if (removed > 0) {
      LiveGoCacheObserver.log('cache_cleanup_done', domain: 'ram', itemCount: removed, reason: 'expired_ram');
    }
  }

  void clearAll() {
    final count = _store.length;
    _store.clear();
    LiveGoCacheObserver.log('cache_cleanup_done', domain: 'ram', itemCount: count, reason: 'clear_runtime_ram');
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
      LiveGoCacheObserver.log('cache_cleanup_done', domain: 'ram', key: entry.key, reason: 'entry_limit');
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
