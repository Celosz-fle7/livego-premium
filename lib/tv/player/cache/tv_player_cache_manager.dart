import '../../../services/cache/livego_cache_observer.dart';
import '../../../models/content_item.dart';
import '../../../models/livego_episode.dart';
import '../../../models/stream_info.dart';

class TvPlayerCacheManager {
  const TvPlayerCacheManager._();

  static const Duration episodeListTtl = Duration(minutes: 20);

  // Stream URLs can be short-lived and episode switching must not reuse stale
  // video URLs for too long. Keep all player cache short-lived and bounded.
  static const Duration streamInfoTtl = Duration(seconds: 75);
  static const Duration failedStreamTtl = Duration(minutes: 3);

  static const int _maxEpisodeLists = 24;
  static const int _maxEpisodesPerList = 80;
  static const int _maxEpisodeInFlight = 12;
  static const int _maxStreamEntries = 64;
  static const int _maxFailedEntries = 64;

  static final Map<String, _EpisodeListCacheEntry> _episodeLists =
      <String, _EpisodeListCacheEntry>{};
  static final Map<String, Future<List<LiveGoEpisode>>> _episodeInFlight =
      <String, Future<List<LiveGoEpisode>>>{};

  static final Map<String, _StreamCacheEntry> _streams =
      <String, _StreamCacheEntry>{};
  static final Map<String, DateTime> _failedStreams =
      <String, DateTime>{};

  static Future<List<LiveGoEpisode>> episodesFor(
    ContentItem item, {
    required Future<List<LiveGoEpisode>> Function() loader,
  }) async {
    _prune();

    final key = _contentKey(item);
    final now = DateTime.now();
    final cached = _episodeLists[key];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      LiveGoCacheObserver.log('player_episode_cache_hit', domain: 'player', key: key, itemCount: cached.rows.length, ttl: cached.expiresAt.difference(now));
      return List<LiveGoEpisode>.unmodifiable(cached.rows);
    }
    if (cached != null) {
      LiveGoCacheObserver.log('player_episode_cache_expired', domain: 'player', key: key, expired: true);
      _episodeLists.remove(key);
    }

    final existing = _episodeInFlight[key];
    if (existing != null) {
      LiveGoCacheObserver.log('player_inflight_join', domain: 'player', key: key);
      return existing;
    }

    final request = () async {
      final rows = await loader();
      if (rows.isNotEmpty) {
        _episodeLists[key] = _EpisodeListCacheEntry(
          rows: List<LiveGoEpisode>.unmodifiable(rows.take(_maxEpisodesPerList)),
          expiresAt: DateTime.now().add(episodeListTtl),
        );
        LiveGoCacheObserver.log('player_episode_cache_saved', domain: 'player', key: key, itemCount: rows.length, ttl: episodeListTtl);
        _limitEpisodeLists();
      }
      return rows;
    }();

    _episodeInFlight[key] = request;
    _limitEpisodeInFlight();
    try {
      return await request;
    } finally {
      if (_episodeInFlight[key] == request) {
        _episodeInFlight.remove(key);
      }
    }
  }

  static List<LiveGoEpisode>? cachedEpisodes(ContentItem item) {
    _prune();
    final cached = _episodeLists[_contentKey(item)];
    if (cached == null) return null;
    if (cached.expiresAt.isBefore(DateTime.now())) {
      _episodeLists.remove(_contentKey(item));
      LiveGoCacheObserver.log('player_episode_cache_expired', domain: 'player', key: _contentKey(item), expired: true);
      return null;
    }
    return List<LiveGoEpisode>.unmodifiable(cached.rows);
  }

  static StreamInfo? streamFor(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) {
    _prune();
    final key = _streamKey(item, chapterId, episode);
    final cached = _streams[key];
    if (cached == null) return null;
    if (cached.expiresAt.isBefore(DateTime.now())) {
      _streams.remove(key);
      LiveGoCacheObserver.log('player_stream_cache_expired', domain: 'player', key: key, expired: true);
      return null;
    }
    LiveGoCacheObserver.log('player_stream_cache_hit', domain: 'player', key: key, ttl: cached.expiresAt.difference(DateTime.now()));
    return cached.stream;
  }

  static void saveStream(
    ContentItem item, {
    required String chapterId,
    required int episode,
    required StreamInfo stream,
  }) {
    final url = stream.url.trim();
    if (url.isEmpty) return;

    final key = _streamKey(item, chapterId, episode);
    _streams[key] = _StreamCacheEntry(
      stream: stream,
      expiresAt: DateTime.now().add(streamInfoTtl),
    );
    _failedStreams.remove(key);
    LiveGoCacheObserver.log('player_stream_cache_saved', domain: 'player', key: key, ttl: streamInfoTtl);
    _limitStreams();
  }

  static bool isStreamRecentlyFailed(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) {
    _prune();
    final until = _failedStreams[_streamKey(item, chapterId, episode)];
    final active = until != null && until.isAfter(DateTime.now());
    if (active) {
      LiveGoCacheObserver.log('player_failed_cooldown_hit', domain: 'player', key: _streamKey(item, chapterId, episode), ttl: until.difference(DateTime.now()));
    }
    return active;
  }

  static void markStreamFailed(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) {
    final key = _streamKey(item, chapterId, episode);
    _failedStreams[key] = DateTime.now().add(failedStreamTtl);
    LiveGoCacheObserver.log('player_failed_cooldown_saved', domain: 'player', key: key, ttl: failedStreamTtl);
    _limitFailed();
  }

  static void clearForItem(ContentItem item) {
    final prefix = '${_contentKey(item)}|';
    _episodeLists.remove(_contentKey(item));
    _episodeInFlight.remove(_contentKey(item));
    _streams.removeWhere((key, _) => key.startsWith(prefix));
    _failedStreams.removeWhere((key, _) => key.startsWith(prefix));
    LiveGoCacheObserver.log('player_cache_cleanup', domain: 'player', key: _contentKey(item), reason: 'clear_item');
  }

  static void clearAll() {
    final count = _episodeLists.length + _episodeInFlight.length + _streams.length + _failedStreams.length;
    _episodeLists.clear();
    _episodeInFlight.clear();
    _streams.clear();
    _failedStreams.clear();
    LiveGoCacheObserver.log('player_cache_cleanup', domain: 'player', itemCount: count, reason: 'clear_all_runtime');
  }

  static void _prune() {
    final now = DateTime.now();
    var removed = 0;
    _episodeLists.removeWhere((_, entry) {
      final expired = !entry.expiresAt.isAfter(now);
      if (expired) removed++;
      return expired;
    });
    _streams.removeWhere((_, entry) {
      final expired = !entry.expiresAt.isAfter(now);
      if (expired) removed++;
      return expired;
    });
    _failedStreams.removeWhere((_, until) {
      final expired = !until.isAfter(now);
      if (expired) removed++;
      return expired;
    });
    if (removed > 0) {
      LiveGoCacheObserver.log('player_cache_cleanup', domain: 'player', itemCount: removed, reason: 'expired_runtime');
    }
    _limitEpisodeLists();
    _limitEpisodeInFlight();
    _limitStreams();
    _limitFailed();
  }

  static void _limitEpisodeLists() {
    if (_episodeLists.length <= _maxEpisodeLists) return;
    final removeCount = _episodeLists.length - _maxEpisodeLists;
    for (final key in _episodeLists.keys.take(removeCount).toList()) {
      _episodeLists.remove(key);
      LiveGoCacheObserver.log('player_cache_cleanup', domain: 'player', key: key, reason: 'episode_list_limit');
    }
  }

  static void _limitEpisodeInFlight() {
    if (_episodeInFlight.length <= _maxEpisodeInFlight) return;
    final removeCount = _episodeInFlight.length - _maxEpisodeInFlight;
    for (final key in _episodeInFlight.keys.take(removeCount).toList()) {
      _episodeInFlight.remove(key);
      LiveGoCacheObserver.log('player_cache_cleanup', domain: 'player', key: key, reason: 'inflight_limit');
    }
  }

  static void _limitStreams() {
    if (_streams.length <= _maxStreamEntries) return;
    final removeCount = _streams.length - _maxStreamEntries;
    for (final key in _streams.keys.take(removeCount).toList()) {
      _streams.remove(key);
      LiveGoCacheObserver.log('player_cache_cleanup', domain: 'player', key: key, reason: 'stream_limit');
    }
  }

  static void _limitFailed() {
    if (_failedStreams.length <= _maxFailedEntries) return;
    final removeCount = _failedStreams.length - _maxFailedEntries;
    for (final key in _failedStreams.keys.take(removeCount).toList()) {
      _failedStreams.remove(key);
      LiveGoCacheObserver.log('player_cache_cleanup', domain: 'player', key: key, reason: 'failed_limit');
    }
  }

  static String _contentKey(ContentItem item) {
    return [
      item.platformSlug.trim(),
      item.id.trim(),
    ].join(':');
  }

  static String _streamKey(ContentItem item, String chapterId, int episode) {
    return [
      _contentKey(item),
      chapterId.trim(),
      episode,
    ].join('|');
  }
}

class _EpisodeListCacheEntry {
  final List<LiveGoEpisode> rows;
  final DateTime expiresAt;

  const _EpisodeListCacheEntry({
    required this.rows,
    required this.expiresAt,
  });
}

class _StreamCacheEntry {
  final StreamInfo stream;
  final DateTime expiresAt;

  const _StreamCacheEntry({
    required this.stream,
    required this.expiresAt,
  });
}
