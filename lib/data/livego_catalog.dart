import '../core/livego_settings.dart';
import '../models/content_item.dart';
import '../models/stream_info.dart';
import '../services/anichin_api_client.dart';
import '../services/cache/livego_content_cache.dart';
import '../models/livego_episode.dart';
import 'mock_catalog.dart';

class LiveGoCatalog {
  static List<String> get platforms {
    final chosen = LiveGoSettings.homePlatforms.where(LiveGoSettings.isPlatformActive).take(6).toList();
    if (chosen.isNotEmpty) return chosen;
    final active = LiveGoSettings.activePlatforms.take(6).toList();
    return active.isEmpty ? AnichinApiClient.defaultPlatforms : active;
  }

  static List<String> get allPlatforms => AnichinApiClient.supportedPlatforms;
  static List<String> get platformLabels => platforms.map(label).toList();
  static List<String> labelsFor(List<String> values) => values.map(label).toList();
  static List<String> get categories => categoriesFor(platforms.isEmpty ? 'shortmax' : platforms.first);

  static List<String> categoriesFor(String platform) => LiveGoSettings.categoriesFor(platform).take(6).toList();

  static Future<List<String>> fetchCategoriesFor(String platform) async {
    return categoriesFor(platform);
  }

  static Future<String> pingPlatform(String platform) async {
    final start = DateTime.now();
    try {
      final rows = await AnichinApiClient.home(platform: platform, lang: LiveGoSettings.language);
      if (rows.isEmpty) {
        LiveGoSettings.setPlatformStatus(platform, 'offline');
        return 'offline';
      }
      final ms = DateTime.now().difference(start).inMilliseconds;
      final status = ms > 2500 ? 'slow' : 'online';
      LiveGoSettings.setPlatformStatus(platform, status);
      return status;
    } catch (e) {
      print('LIVEGO PING ERROR $platform: $e');
      LiveGoSettings.setPlatformStatus(platform, 'offline');
      return 'offline';
    }
  }

  static Future<List<ContentItem>> home({String platform = 'shortmax'}) async {
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: 'home',
      params: {'lang': LiveGoSettings.language},
    );
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final rows = await AnichinApiClient.home(platform: platform, lang: LiveGoSettings.language)
          .timeout(const Duration(seconds: 12));
      print('CATALOG HOME $platform -> ${rows.length}');
      if (rows.isNotEmpty) {
        await LiveGoContentCache.writeItems(
          platform: platform,
          endpoint: 'home',
          params: {'lang': LiveGoSettings.language},
          items: rows,
        );
        return rows;
      }
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }

    try {
      final rows = await AnichinApiClient.discover(platform: platform, lang: LiveGoSettings.language)
          .timeout(const Duration(seconds: 12));
      if (rows.isNotEmpty) {
        await LiveGoContentCache.writeItems(
          platform: platform,
          endpoint: 'home',
          params: {'lang': LiveGoSettings.language},
          items: rows,
        );
        return rows;
      }
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }

    return [];
  }


  static Future<List<ContentItem>> homeByCategory({
    String platform = 'shortmax',
    String category = 'Trending',
  }) async {
    final key = category.trim().toLowerCase().replaceAll(' ', '');
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: key.isEmpty ? 'home' : key,
      params: {'lang': LiveGoSettings.language},
    );
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      if (key == 'foryou') {
        final rows = await AnichinApiClient.discover(platform: platform, lang: LiveGoSettings.language)
            .timeout(const Duration(seconds: 12));
        if (rows.isNotEmpty) {
          await LiveGoContentCache.writeItems(
            platform: platform,
            endpoint: key,
            params: {'lang': LiveGoSettings.language},
            items: rows,
          );
          return rows;
        }
      }
      if (platform == 'dramabox' && (key == 'latest' || key == 'vip' || key == 'dubindo')) {
        final rows = await AnichinApiClient.collection(
          platform: platform,
          collection: key,
          lang: LiveGoSettings.language,
        ).timeout(const Duration(seconds: 12));
        if (rows.isNotEmpty) {
          await LiveGoContentCache.writeItems(
            platform: platform,
            endpoint: key,
            params: {'lang': LiveGoSettings.language},
            items: rows,
          );
          return rows;
        }
      }
    } catch (e) { print('LIVEGO CATEGORY ERROR: $e'); }
    final rows = await home(platform: platform);
    if (rows.isNotEmpty) {
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: key.isEmpty ? 'home' : key,
        params: {'lang': LiveGoSettings.language},
        items: rows,
      );
    }
    return rows;
  }

  static Future<Map<String, List<ContentItem>>> homeSections() async {
    await LiveGoContentCache.cleanExpiredAndTrim();
    final futures = platforms.take(6).map((platform) async {
      final rows = await home(platform: platform);
      return MapEntry(label(platform), rows);
    });
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries.where((e) => e.value.isNotEmpty));
  }

  static Future<List<ContentItem>> banners({String platform = 'shortmax'}) async {
    final items = await home(platform: platform);
    if (items.isNotEmpty) return items.take(5).toList();
    return [];
  }

  static Future<ContentItem> hero({String platform = 'shortmax'}) async {
    try {
      final items = await home(platform: platform);
      if (items.isNotEmpty) return items.first;
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }
    return MockCatalog.hero;
  }

  static Future<List<ContentItem>> search(String query, {String platform = 'shortmax'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: 'search',
      params: {'q': clean, 'lang': LiveGoSettings.language},
    );
    if (cached != null) return cached;
    try {
      final rows = await AnichinApiClient.search(query: clean, platform: platform, lang: LiveGoSettings.language);
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: 'search',
        params: {'q': clean, 'lang': LiveGoSettings.language},
        items: rows,
        ttl: LiveGoContentCache.searchTtl,
      );
      return rows;
    } catch (e) {
      print('LIVEGO SEARCH ERROR: $e');
      return [];
    }
  }

  static Future<List<ContentItem>> searchAll(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final merged = <ContentItem>[];
    final seen = <String>{};
    for (final platform in platforms) {
      final rows = await search(clean, platform: platform);
      for (final item in rows) {
        final key = '${item.platformSlug}:${item.id}';
        if (seen.add(key)) merged.add(item);
      }
    }
    return merged;
  }

  static Future<ContentItem> detail(ContentItem item) async {
    final cached = await LiveGoContentCache.readDetail(item);
    if (cached != null) return cached;
    try {
      final detail = await AnichinApiClient.detail(item);
      final resolved = detail ?? item;
      await LiveGoContentCache.writeDetail(resolved);
      return resolved;
    } catch (e) {
      print('LIVEGO DETAIL ERROR: $e');
      return item;
    }
  }


  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async {
    final cached = await LiveGoContentCache.readEpisodes(item);
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final rows = await AnichinApiClient.episodes(item).timeout(const Duration(seconds: 12));
      if (rows.isNotEmpty) await LiveGoContentCache.writeEpisodes(item, rows);
      return rows;
    } catch (e) {
      print('LIVEGO EPISODES ERROR: $e');
      final total = item.episodes <= 0 ? 1 : item.episodes;
      return List.generate(total, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'));
    }
  }

  static Future<int> episodeCount(ContentItem item) async {
    final rows = await episodes(item);
    return rows.isEmpty ? (item.episodes <= 0 ? 1 : item.episodes) : rows.length;
  }

  static Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) async {
    try {
      return await AnichinApiClient.videoInfo(item, chapterId: chapterId ?? item.chapterId);
    } catch (e) {
      print('LIVEGO STREAM ERROR: $e');
      return StreamInfo.empty;
    }
  }

  static Future<String> videoUrl(ContentItem item) async {
    final info = await streamInfo(item, chapterId: item.chapterId);
    return info.url;
  }

  static String label(String slug) {
    return slug
        .split(RegExp(r'[_-]'))
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }
}
