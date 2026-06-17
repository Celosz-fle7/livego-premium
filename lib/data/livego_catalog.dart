import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'catalog/livego_catalog_detail_player_service.dart';
import 'catalog/livego_catalog_home_service.dart';
import 'catalog/livego_catalog_platform_service.dart';
import 'catalog/livego_catalog_search_service.dart';

/// Public facade for app features.
///
/// Keep this file thin. Home/Search/Detail/Player logic lives under
/// `lib/data/catalog/` so API changes do not make this file grow again.
class LiveGoCatalog {
  static List<String> get platforms => LiveGoCatalogPlatformService.platforms;
  static List<String> get allPlatforms => LiveGoCatalogPlatformService.allPlatforms;
  static List<String> get platformLabels => LiveGoCatalogPlatformService.platformLabels;
  static List<String> labelsFor(List<String> values) => LiveGoCatalogPlatformService.labelsFor(values);
  static List<String> get categories => LiveGoCatalogPlatformService.categories;
  static List<String> categoriesFor(String platform) => LiveGoCatalogPlatformService.categoriesFor(platform);
  static List<String> availableCategoriesFor(String platform) => LiveGoCatalogPlatformService.availableCategoriesFor(platform);
  static List<String> languagesFor(String platform) => LiveGoCatalogPlatformService.languagesFor(platform);
  static String languageFor(String platform) => LiveGoCatalogPlatformService.languageFor(platform);
  static String backendLabel(String platform) => LiveGoCatalogPlatformService.backendLabel(platform);
  static bool isNobuzeroPlatform(String platform) => LiveGoCatalogPlatformService.isNobuzeroPlatform(platform);
  static Future<List<String>> fetchCategoriesFor(String platform) => LiveGoCatalogPlatformService.fetchCategoriesFor(platform);
  static Future<String> pingPlatform(String platform) => LiveGoCatalogPlatformService.pingPlatform(platform);
  static String label(String slug) => LiveGoCatalogPlatformService.label(slug);

  static Future<List<ContentItem>> home({String platform = 'nobuzero_freereels'}) =>
      LiveGoCatalogHomeService.home(platform: platform);

  static Future<List<ContentItem>> cachedHomeByCategory({
    String platform = 'nobuzero_freereels',
    String category = 'Home',
    bool allowExpired = true,
  }) =>
      LiveGoCatalogHomeService.cachedHomeByCategory(
        platform: platform,
        category: category,
        allowExpired: allowExpired,
      );

  static Future<List<ContentItem>> homeByCategory({
    String platform = 'nobuzero_freereels',
    String category = 'Home',
  }) =>
      LiveGoCatalogHomeService.homeByCategory(platform: platform, category: category);

  static Future<Map<String, List<ContentItem>>> homeSections() =>
      LiveGoCatalogHomeService.homeSections();

  static Future<List<ContentItem>> banners({String platform = 'nobuzero_freereels'}) =>
      LiveGoCatalogHomeService.banners(platform: platform);

  static Future<ContentItem> hero({String platform = 'nobuzero_freereels'}) =>
      LiveGoCatalogHomeService.hero(platform: platform);

  static Future<List<ContentItem>> search(String query, {String platform = 'nobuzero_freereels'}) =>
      LiveGoCatalogSearchService.search(query, platform: platform);

  static Future<List<ContentItem>> searchAll(String query) =>
      LiveGoCatalogSearchService.searchAll(query);

  static Future<ContentItem> detail(ContentItem item) =>
      LiveGoCatalogDetailPlayerService.detail(item);

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) =>
      LiveGoCatalogDetailPlayerService.episodes(item);

  static Future<int> episodeCount(ContentItem item) =>
      LiveGoCatalogDetailPlayerService.episodeCount(item);

  static Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) =>
      LiveGoCatalogDetailPlayerService.streamInfo(item, chapterId: chapterId);

  static Future<StreamInfo> fastStreamInfo(
    ContentItem item, {
    String? chapterId,
    Duration? timeout,
  }) =>
      LiveGoCatalogDetailPlayerService.fastStreamInfo(
        item,
        chapterId: chapterId,
        timeout: timeout,
      );

  static Future<String> videoUrl(ContentItem item) =>
      LiveGoCatalogDetailPlayerService.videoUrl(item);
}
