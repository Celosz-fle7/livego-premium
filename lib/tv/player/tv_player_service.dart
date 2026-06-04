import 'package:flutter/foundation.dart';

import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../../services/player/playback_resolver.dart';
import '../../services/player/playback_timeout_config.dart';

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
class TvPlayerService {
  const TvPlayerService();

  Future<TvPlayerStreamResolveResult> resolveStream(
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

    // 4) Last detail warm-up fallback. Some APIs need detail/episode cache filled
    // before a stream becomes available.
    await wrap(
      'detailWarmup',
      () async {
        await LiveGoCatalog.detail(item).timeout(PlaybackTimeoutConfig.detailBackground);
        return StreamInfo.empty;
      },
    );

    result = await wrap(
      'postDetailStreamInfo',
      () => LiveGoCatalog.streamInfo(item, chapterId: chapterId)
          .timeout(const Duration(seconds: 8), onTimeout: () => StreamInfo.empty),
    );
    if (result.hasStream) return result;

    return result;
  }

  Future<StreamInfo> fastStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    return LiveGoCatalog.fastStreamInfo(item, chapterId: chapterId, timeout: timeout);
  }

  Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) {
    return LiveGoCatalog.streamInfo(item, chapterId: chapterId);
  }

  Future<ContentItem> detail(ContentItem item) {
    return LiveGoCatalog.detail(item);
  }

  Future<List<LiveGoEpisode>> episodes(ContentItem item) {
    return LiveGoCatalog.episodes(item);
  }
}
