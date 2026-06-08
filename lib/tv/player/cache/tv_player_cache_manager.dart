import '../../../models/content_item.dart';
import '../../../models/livego_episode.dart';
import '../../../models/stream_info.dart';

class TvPlayerCacheManager {
  const TvPlayerCacheManager._();

  static const Duration episodeListTtl = Duration(hours: 24);

  // Stream URLs can be short-lived and episode switching must not reuse stale
  // video URLs for too long. Keep this small; episode list cache remains long.
  static const Duration streamInfoTtl = Duration(seconds: 90);
  static const Duration failedStreamTtl = Duration(minutes: 3);

  static const int _maxEpisodeLists = 80;
  static const int _maxEpisodeInFlight = 24;
  static const int _maxStreamEntries = 240;
  static const int _maxFailedEntries = 160;

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
      return List<LiveGoEpisode>.unmodifiable(cached.rows);
    }

    final existing = _episodeInFlight[key];
    if (existing != null) return existing;

    final request = () async {
      final rows = await loader();
      if (rows.isNotEmpty) {
        _episodeLists[key] = _EpisodeListCacheEntry(
          rows: List<LiveGoEpisode>.unmodifiable(rows),
          expiresAt: DateTime.now().add(episodeListTtl),
        );
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
    if (cached == null || cached.expiresAt.isBefore(DateTime.now())) {
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
    if (cached == null || cached.expiresAt.isBefore(DateTime.now())) {
      _streams.remove(key);
      return null;
    }
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
    _limitStreams();
  }

  static bool isStreamRecentlyFailed(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) {
    _prune();
    final until = _failedStreams[_streamKey(item, chapterId, episode)];
    return until != null && until.isAfter(DateTime.now());
  }

  static void markStreamFailed(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) {
    _failedStreams[_streamKey(item, chapterId, episode)] =
        DateTime.now().add(failedStreamTtl);
    _limitFailed();
  }

  static void clearForItem(ContentItem item) {
    final prefix = '${_contentKey(item)}|';
    _episodeLists.remove(_contentKey(item));
    _episodeInFlight.remove(_contentKey(item));
    _streams.removeWhere((key, _) => key.startsWith(prefix));
    _failedStreams.removeWhere((key, _) => key.startsWith(prefix));
  }

  static void clearAll() {
    _episodeLists.clear();
    _episodeInFlight.clear();
    _streams.clear();
    _failedStreams.clear();
  }

  static void _prune() {
    final now = DateTime.now();
    _episodeLists.removeWhere((_, entry) => !entry.expiresAt.isAfter(now));
    _streams.removeWhere((_, entry) => !entry.expiresAt.isAfter(now));
    _failedStreams.removeWhere((_, until) => !until.isAfter(now));
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
    }
  }

  static void _limitEpisodeInFlight() {
    if (_episodeInFlight.length <= _maxEpisodeInFlight) return;
    final removeCount = _episodeInFlight.length - _maxEpisodeInFlight;
    for (final key in _episodeInFlight.keys.take(removeCount).toList()) {
      _episodeInFlight.remove(key);
    }
  }

  static void _limitStreams() {
    if (_streams.length <= _maxStreamEntries) return;
    final removeCount = _streams.length - _maxStreamEntries;
    for (final key in _streams.keys.take(removeCount).toList()) {
      _streams.remove(key);
    }
  }

  static void _limitFailed() {
    if (_failedStreams.length <= _maxFailedEntries) return;
    final removeCount = _failedStreams.length - _maxFailedEntries;
    for (final key in _failedStreams.keys.take(removeCount).toList()) {
      _failedStreams.remove(key);
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
