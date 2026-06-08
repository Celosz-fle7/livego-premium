import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../../services/cache/livego_content_cache.dart';
import '../../services/player/playback_resolver.dart';
import '../api_manager/api_provider_registry.dart';
import '../api_manager/api_timeout_policy.dart';
import '../api_manager/livego_api_manager.dart';

class LiveGoCatalogDetailPlayerService {
  const LiveGoCatalogDetailPlayerService._();

  static Future<ContentItem> detail(ContentItem item) async {
    final cached = await LiveGoContentCache.readDetail(item);
    if (cached != null) {
      final resolvedCached = _preservePlayableIdentity(cached, item);
      if (resolvedCached.id.isNotEmpty) return resolvedCached;
    }

    final detail = await LiveGoApiManager.fetchDetail(
      item: item,
      request: () => LiveGoApiProviderRegistry.providerFor(item.platformSlug).detail(item),
      fallback: item,
    );

    final resolved = _preservePlayableIdentity(detail ?? item, item);
    await LiveGoContentCache.writeDetail(resolved);
    return resolved;
  }

  static ContentItem _preservePlayableIdentity(ContentItem detail, ContentItem original) {
    return ContentItem(
      id: detail.id.trim().isNotEmpty ? detail.id : original.id,
      title: detail.title.trim().isNotEmpty ? detail.title : original.title,
      source: detail.source.trim().isNotEmpty ? detail.source : original.source,
      category: detail.category.trim().isNotEmpty ? detail.category : original.category,
      description: detail.description.trim().isNotEmpty ? detail.description : original.description,
      posterUrl: detail.posterUrl.trim().isNotEmpty ? detail.posterUrl : original.posterUrl,
      backdropUrl: detail.backdropUrl.trim().isNotEmpty ? detail.backdropUrl : original.backdropUrl,
      rating: detail.rating,
      episodes: detail.episodes > 0 ? detail.episodes : original.episodes,
      updated: detail.updated || original.updated,
      platformSlug: detail.platformSlug.trim().isNotEmpty ? detail.platformSlug : original.platformSlug,
      chapterId: detail.chapterId.trim().isNotEmpty ? detail.chapterId : original.chapterId,
      lang: detail.lang.trim().isNotEmpty ? detail.lang : original.lang,
    );
  }

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async {
    final cached = await LiveGoContentCache.readEpisodes(item);

    // Older fast-start builds could cache a synthetic fallback containing only
    // Episode 1 before /detail finished. Do not trust a single-row episode
    // cache for providers that normally expose a full episode list; refresh it
    // from the active LiveGo source so the player sheet shows all episodes again.
    if (cached != null && cached.length > 1) return cached;

    final rows = await LiveGoApiManager.fetchEpisodes(
      item: item,
      request: () => LiveGoApiProviderRegistry.providerFor(item.platformSlug).episodes(item),
      fallback: cached ?? const <LiveGoEpisode>[],
    );
    if (rows.length > 1) {
      await LiveGoContentCache.writeEpisodes(item, rows);
      return rows;
    }

    // If the network still cannot provide the full list, only then fall back
    // to the old cached single episode or item.episodes. Never overwrite a
    // good future cache with this one-row fallback.
    if (cached != null && cached.isNotEmpty) return cached;
    if (rows.isNotEmpty) return rows;

    final total = item.episodes <= 0 ? 1 : item.episodes;
    return List.generate(total, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'));
  }

  static Future<int> episodeCount(ContentItem item) async {
    final rows = await episodes(item);
    return rows.isEmpty ? (item.episodes <= 0 ? 1 : item.episodes) : rows.length;
  }

  static Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) async {
    return LiveGoApiManager.fetchStreamInfo(
      item: item,
      timeout: ApiTimeoutPolicy.video,
      request: () => PlaybackResolver.resolveStreamInfo(item, chapterId: chapterId ?? item.chapterId),
    );
  }

  static Future<StreamInfo> fastStreamInfo(
    ContentItem item, {
    String? chapterId,
    Duration? timeout,
  }) async {
    return LiveGoApiManager.fetchStreamInfo(
      item: item,
      timeout: timeout ?? const Duration(seconds: 6),
      request: () => PlaybackResolver.fastStreamInfo(
        item,
        chapterId: chapterId ?? item.chapterId,
        timeout: timeout ?? const Duration(seconds: 6),
      ),
    );
  }

  static Future<String> videoUrl(ContentItem item) async {
    final info = await streamInfo(item, chapterId: item.chapterId);
    return info.url;
  }
}
