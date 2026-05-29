import '../core/livego_settings.dart';
import '../models/content_item.dart';
import '../models/stream_info.dart';
import '../services/api_drama_client.dart';
import 'mock_catalog.dart';

class LiveGoCatalog {
  static List<String> get platforms {
    final chosen = LiveGoSettings.homePlatforms.where(LiveGoSettings.isPlatformActive).take(6).toList();
    if (chosen.isNotEmpty) return chosen;
    final active = LiveGoSettings.activePlatforms.take(6).toList();
    return active.isEmpty ? ApiDramaClient.defaultPlatforms : active;
  }

  static List<String> get allPlatforms => ApiDramaClient.supportedPlatforms;
  static List<String> get platformLabels => platforms.map(label).toList();
  static List<String> labelsFor(List<String> values) => values.map(label).toList();
  static List<String> get categories => categoriesFor(platforms.isEmpty ? 'freereels' : platforms.first);

  static List<String> categoriesFor(String platform) => LiveGoSettings.categoriesFor(platform).take(6).toList();

  static Future<List<String>> fetchCategoriesFor(String platform) async {
    try {
      final rows = await home(platform: platform).timeout(const Duration(seconds: 12));
      final seen = <String>{};
      final values = <String>[];
      for (final item in rows) {
        final c = item.category.trim();
        if (c.isNotEmpty && c.toLowerCase() != 'drama' && seen.add(c.toLowerCase())) values.add(c);
        if (values.length >= 12) break;
      }
      if (values.isNotEmpty) return values;
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }
    return const ['Trending', 'New', 'Drama', 'Movies', 'Anime', 'Dubbing'];
  }

  static Future<String> pingPlatform(String platform) async {
    final start = DateTime.now();
    try {
      final rows = await ApiDramaClient.home(platform: platform, lang: LiveGoSettings.language);
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

  static Future<List<ContentItem>> home({String platform = 'freereels'}) async {
    try {
      final rows = await ApiDramaClient.home(platform: platform, lang: LiveGoSettings.language)
          .timeout(const Duration(seconds: 12));
      if (rows.isNotEmpty) return rows;
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }

    try {
      final rows = await ApiDramaClient.discover(platform: platform, lang: LiveGoSettings.language)
          .timeout(const Duration(seconds: 12));
      if (rows.isNotEmpty) return rows;
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }

    return [];
  }

  static Future<Map<String, List<ContentItem>>> homeSections() async {
    final result = <String, List<ContentItem>>{};
    for (final platform in platforms.take(6)) {
      final rows = await home(platform: platform);
      if (rows.isNotEmpty) result[label(platform)] = rows;
    }
    return result;
  }

  static Future<List<ContentItem>> banners({String platform = 'freereels'}) async {
    try {
      final banners = await ApiDramaClient.banner(platform: platform, lang: LiveGoSettings.language)
          .timeout(const Duration(seconds: 10));
      if (banners.isNotEmpty) return banners.take(8).toList();
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }

    final items = await home(platform: platform);
    return items.take(5).toList();
  }

  static Future<ContentItem> hero({String platform = 'freereels'}) async {
    try {
      final banners = await ApiDramaClient.banner(platform: platform, lang: LiveGoSettings.language);
      if (banners.isNotEmpty) return banners.first;
      final items = await home(platform: platform);
      if (items.isNotEmpty) return items.first;
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }
    return MockCatalog.hero;
  }

  static Future<List<ContentItem>> search(String query, {String platform = 'freereels'}) async {
    try {
      return await ApiDramaClient.search(query: query, platform: platform, lang: LiveGoSettings.language);
    } catch (_) {
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
    try {
      final detail = await ApiDramaClient.detail(item);
      return detail ?? item;
    } catch (_) {
      return item;
    }
  }

  static Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) async {
    try {
      return await ApiDramaClient.videoInfo(item, chapterId: chapterId ?? item.chapterId);
    } catch (_) {
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
