import '../models/content_item.dart';
import '../services/api_drama_client.dart';
import 'mock_catalog.dart';

class LiveGoCatalog {
  static List<String> get platforms => ApiDramaClient.defaultPlatforms;
  static List<String> get platformLabels => platforms.map(_label).toList();
  static List<String> get categories => MockCatalog.categories.take(6).toList();

  static Future<List<ContentItem>> home({String platform = 'freereels'}) async {
    try {
      final items = await ApiDramaClient.home(platform: platform);
      return items.isNotEmpty ? items : MockCatalog.items;
    } catch (_) {
      return MockCatalog.items;
    }
  }

  static Future<ContentItem> hero({String platform = 'freereels'}) async {
    try {
      final banners = await ApiDramaClient.banner(platform: platform);
      if (banners.isNotEmpty) return banners.first;
      final items = await home(platform: platform);
      if (items.isNotEmpty) return items.first;
    } catch (_) {}
    return MockCatalog.hero;
  }

  static Future<List<ContentItem>> search(String query, {String platform = 'freereels'}) async {
    try {
      final items = await ApiDramaClient.search(query: query, platform: platform);
      return items.isNotEmpty ? items : MockCatalog.search(query);
    } catch (_) {
      return MockCatalog.search(query);
    }
  }

  static Future<ContentItem> detail(ContentItem item) async {
    try {
      final detail = await ApiDramaClient.detail(item);
      return detail ?? item;
    } catch (_) {
      return item;
    }
  }

  static Future<String> videoUrl(ContentItem item) async {
    try {
      return await ApiDramaClient.videoUrl(item, chapterId: item.chapterId);
    } catch (_) {
      return '';
    }
  }

  static String _label(String slug) {
    return slug
        .split(RegExp(r'[_-]'))
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }
}
