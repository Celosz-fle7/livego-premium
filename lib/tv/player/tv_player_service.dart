import 'package:flutter/foundation.dart';

import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../../services/player/playback_contract.dart';
import '../../services/player/playback_resolver.dart';
import '../../services/player/playback_timeout_config.dart';
import 'cache/tv_player_cache_manager.dart';

class TvPlayerStreamResolveResult {
  final StreamInfo stream;
  final String source;
  final int elapsedMs;

  const TvPlayerStreamResolveResult({
    required this.stream,
    required this.source,
    required this.elapsedMs,
  });

  bool get hasStream => stream.url.trim().isNotEmpty;
}

/// Player data/service boundary.
///
/// VideoPlayerController ownership still stays in TvPlayerScreen for stability.
/// Stream resolving/fallback is owned here so the screen does not decide API order.
class TvPlayerService implements PlaybackContract {
  const TvPlayerService();

  static const Duration _streamMissCooldown = Duration(seconds: 18);
  static const Duration _streamResolveTimeout = Duration(seconds: 14);
  static const Duration _prefetchResolveTimeout = Duration(seconds: 8);
  static const int _maxInFlightRequests = 24;
  static const int _maxRecentMiss = 80;

  static final Map<String, Future<TvPlayerStreamResolveResult>> _inFlight =
      <String, Future<TvPlayerStreamResolveResult>>{};
  static final Map<String, DateTime> _inFlightStartedAt = <String, DateTime>{};
  static final Map<String, DateTime> _recentMiss = <String, DateTime>{};

  Future<TvPlayerStreamResolveResult> resolveStream(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) async {
    final budgetKey = _streamBudgetKey(item, chapterId, episode);
    _pruneRequestBudget();

    final cachedStream = TvPlayerCacheManager.streamFor(
      item,
      chapterId: chapterId,
      episode: episode,
    );
    if (cachedStream != null && cachedStream.url.trim().isNotEmpty) {
      debugPrint('LIVEGO TV STREAM CACHE HIT ep=$episode chapter=$chapterId');
      return TvPlayerStreamResolveResult(
        stream: cachedStream,
        source: 'cache',
        elapsedMs: 0,
      );
    }

    if (TvPlayerCacheManager.isStreamRecentlyFailed(
      item,
      chapterId: chapterId,
      episode: episode,
    )) {
      debugPrint('LIVEGO TV STREAM CACHE FAILED_COOLDOWN ep=$episode chapter=$chapterId');
      return const TvPlayerStreamResolveResult(
        stream: StreamInfo.empty,
        source: 'cacheFailedCooldown',
        elapsedMs: 0,
      );
    }

    final blockedUntil = _recentMiss[budgetKey];
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      debugPrint('LIVEGO TV STREAM BUDGET RECENT_MISS SKIP ep=$episode chapter=$chapterId');
      return const TvPlayerStreamResolveResult(
        stream: StreamInfo.empty,
        source: 'recentMiss',
        elapsedMs: 0,
      );
    }

    final existing = _inFlight[budgetKey];
    if (existing != null) {
      debugPrint('LIVEGO TV STREAM BUDGET JOIN inFlight ep=$episode chapter=$chapterId');
      return existing;
    }

    if (_inFlight.length >= _maxInFlightRequests) {
      debugPrint('LIVEGO TV STREAM BUDGET FULL skip ep=$episode chapter=$chapterId');
      return const TvPlayerStreamResolveResult(
        stream: StreamInfo.empty,
        source: 'inFlightBudgetFull',
        elapsedMs: 0,
      );
    }

    final request = _resolveStreamUncached(item, chapterId: chapterId, episode: episode)
        .timeout(
          _streamResolveTimeout,
          onTimeout: () => TvPlayerStreamResolveResult(
            stream: StreamInfo.empty,
            source: 'resolveTimeout',
            elapsedMs: _streamResolveTimeout.inMilliseconds,
          ),
        );
    _inFlight[budgetKey] = request;
    _inFlightStartedAt[budgetKey] = DateTime.now();
    try {
      final result = await request;
      if (result.hasStream) {
        _recentMiss.remove(budgetKey);
        TvPlayerCacheManager.saveStream(
          item,
          chapterId: chapterId,
          episode: episode,
          stream: result.stream,
        );
      } else {
        _recentMiss[budgetKey] = DateTime.now().add(_streamMissCooldown);
        TvPlayerCacheManager.markStreamFailed(
          item,
          chapterId: chapterId,
          episode: episode,
        );
      }
      return result;
    } finally {
      if (_inFlight[budgetKey] == request) {
        _inFlight.remove(budgetKey);
      }
      _inFlightStartedAt.remove(budgetKey);
    }
  }

  /// Background-only stream prefetch.
  ///
  /// This is intentionally softer than resolveStream():
  /// - cache hits are returned immediately
  /// - success is saved to TvPlayerCacheManager
  /// - failure is NOT marked as failed/cooldown
  ///   because prefetch can timeout without meaning the episode is broken
  Future<TvPlayerStreamResolveResult> prefetchStream(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) async {
    final cachedStream = TvPlayerCacheManager.streamFor(
      item,
      chapterId: chapterId,
      episode: episode,
    );
    if (cachedStream != null && cachedStream.url.trim().isNotEmpty) {
      return TvPlayerStreamResolveResult(
        stream: cachedStream,
        source: 'prefetchCache',
        elapsedMs: 0,
      );
    }

    if (TvPlayerCacheManager.isStreamRecentlyFailed(
      item,
      chapterId: chapterId,
      episode: episode,
    )) {
      return const TvPlayerStreamResolveResult(
        stream: StreamInfo.empty,
        source: 'prefetchSkippedFailedCooldown',
        elapsedMs: 0,
      );
    }

    final budgetKey = _streamBudgetKey(item, chapterId, episode);
    final existing = _inFlight[budgetKey];
    if (existing != null) {
      return existing;
    }

    _pruneRequestBudget();
    if (_inFlight.length >= _maxInFlightRequests) {
      return const TvPlayerStreamResolveResult(
        stream: StreamInfo.empty,
        source: 'prefetchBudgetFull',
        elapsedMs: 0,
      );
    }

    final request = _resolveStreamUncached(item, chapterId: chapterId, episode: episode)
        .timeout(
          _prefetchResolveTimeout,
          onTimeout: () => TvPlayerStreamResolveResult(
            stream: StreamInfo.empty,
            source: 'prefetchTimeout',
            elapsedMs: _prefetchResolveTimeout.inMilliseconds,
          ),
        );
    _inFlight[budgetKey] = request;
    _inFlightStartedAt[budgetKey] = DateTime.now();
    try {
      final result = await request;
      if (result.hasStream) {
        TvPlayerCacheManager.saveStream(
          item,
          chapterId: chapterId,
          episode: episode,
          stream: result.stream,
        );
      }
      return result.hasStream
          ? TvPlayerStreamResolveResult(
              stream: result.stream,
              source: 'prefetch:${result.source}',
              elapsedMs: result.elapsedMs,
            )
          : result;
    } finally {
      if (_inFlight[budgetKey] == request) {
        _inFlight.remove(budgetKey);
      }
      _inFlightStartedAt.remove(budgetKey);
    }
  }

  Future<TvPlayerStreamResolveResult> _resolveStreamUncached(
    ContentItem item, {
    required String chapterId,
    required int episode,
  }) async {
    final started = DateTime.now();

    Future<TvPlayerStreamResolveResult> wrap(
      String source,
      Future<StreamInfo> Function() request,
    ) async {
      try {
        final stream = await request();
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        debugPrint('LIVEGO TV STREAM $source DONE ${elapsed}ms stream=${stream.url.isNotEmpty} ep=$episode chapter=$chapterId');
        return TvPlayerStreamResolveResult(stream: stream, source: source, elapsedMs: elapsed);
      } catch (error) {
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        debugPrint('LIVEGO TV STREAM $source FAIL ${elapsed}ms ep=$episode chapter=$chapterId error=$error');
        return TvPlayerStreamResolveResult(stream: StreamInfo.empty, source: source, elapsedMs: elapsed);
      }
    }

    // 1) Fast direct episode path: best for quick TV remote episode switching.
    var result = await wrap(
      'fastStream',
      () => PlaybackResolver.fastStreamInfo(
        item,
        chapterId: chapterId,
        timeout: PlaybackTimeoutConfig.directEpisode,
      ),
    );
    if (result.hasStream) return result;

    // 2) Catalog stream path: goes through API manager/contract/fallback.
    result = await wrap(
      'catalogStreamInfo',
      () => LiveGoCatalog.streamInfo(item, chapterId: chapterId)
          .timeout(PlaybackTimeoutConfig.fallbackStream, onTimeout: () => StreamInfo.empty),
    );
    if (result.hasStream) return result;

    // 3) Catalog fast stream fallback, useful if current resolver branch was stale.
    result = await wrap(
      'catalogFastStream',
      () => LiveGoCatalog.fastStreamInfo(
        item,
        chapterId: chapterId,
        timeout: const Duration(seconds: 7),
      ),
    );
    if (result.hasStream) return result;

    // TV Player must not block the remote for slow detail/all-episode warm-up.
    // If the three direct stream paths fail, return quickly and let the player
    // error/skip flow handle it. API detail/episode warm-up belongs outside
    // the active video startup path.
    return result;
  }

  static String _streamBudgetKey(ContentItem item, String chapterId, int episode) {
    return [
      item.platformSlug.trim(),
      item.id.trim(),
      chapterId.trim(),
      episode,
    ].join('|');
  }

  static void _pruneRequestBudget() {
    final now = DateTime.now();

    _recentMiss.removeWhere((_, until) => !now.isBefore(until));

    // Futures cannot be cancelled, but stale references must not block a later
    // episode request forever if a provider/API call hangs.
    final staleWindow = _streamResolveTimeout + const Duration(seconds: 6);
    _inFlightStartedAt.removeWhere((key, started) {
      final stale = now.difference(started) > staleWindow;
      if (stale) _inFlight.remove(key);
      return stale || !_inFlight.containsKey(key);
    });

    if (_inFlight.length > _maxInFlightRequests) {
      final removeCount = _inFlight.length - _maxInFlightRequests;
      for (final key in _inFlight.keys.take(removeCount).toList(growable: false)) {
        _inFlight.remove(key);
        _inFlightStartedAt.remove(key);
      }
    }

    if (_recentMiss.length <= _maxRecentMiss) return;
    final keys = _recentMiss.keys.toList(growable: false);
    for (final key in keys.take(_recentMiss.length - _maxRecentMiss)) {
      _recentMiss.remove(key);
    }
  }

  /// Stable fast stream entry for TV Player.
  ///
  /// API/provider migrations must keep returning normalized StreamInfo here.
  @override
  Future<StreamInfo> fastStreamInfo(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    return LiveGoCatalog.fastStreamInfo(item, chapterId: chapterId, timeout: timeout);
  }

  /// Backward-compatible alias used by older player code.
  Future<StreamInfo> fastStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    return fastStreamInfo(item, chapterId: chapterId, timeout: timeout);
  }

  /// Stable stream entry for TV Player.
  ///
  /// Player UI must not know API baseUrl/key/raw JSON/endpoint details.
  @override
  Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) {
    return LiveGoCatalog.streamInfo(item, chapterId: chapterId);
  }

  Future<ContentItem> detail(ContentItem item) {
    return LiveGoCatalog.detail(item);
  }

  Future<List<LiveGoEpisode>> episodes(ContentItem item) {
    return TvPlayerCacheManager.episodesFor(
      item,
      loader: () => LiveGoCatalog.episodes(item),
    );
  }
}
