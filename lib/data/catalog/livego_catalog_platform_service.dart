import '../../core/livego_settings.dart';
import '../../services/api/api_platform.dart';
import '../../services/livego_api_gateway.dart';
import '../api_manager/api_timeout_policy.dart';
import '../api_manager/api_provider_registry.dart';
import '../api_manager/livego_api_manager.dart';

class LiveGoCatalogPlatformService {
  const LiveGoCatalogPlatformService._();

  static List<String> get platforms {
    final chosen = LiveGoSettings.homePlatforms.where(LiveGoSettings.isPlatformActive).take(6).toList();
    if (chosen.isNotEmpty) return chosen;
    final active = LiveGoSettings.activePlatforms.take(6).toList();
    return active.isEmpty ? LiveGoApiGateway.defaultPlatforms : active;
  }

  static List<String> get allPlatforms => LiveGoApiGateway.supportedPlatforms;

  static List<String> get platformLabels => platforms.map(label).toList();

  static List<String> labelsFor(List<String> values) => values.map(label).toList();

  static List<String> get categories => categoriesFor(platforms.isEmpty ? 'dobda_freereels' : platforms.first);

  static List<String> categoriesFor(String platform) => LiveGoSettings.categoriesFor(platform).take(6).toList();

  static List<String> availableCategoriesFor(String platform) =>
      LiveGoApiPlatforms.categoriesFor(platform).take(8).toList();

  static List<String> languagesFor(String platform) =>
      LiveGoApiPlatforms.languagesFor(platform);

  static String languageFor(String platform) =>
      LiveGoSettings.languageForPlatform(platform);

  static String backendLabel(String platform) =>
      LiveGoApiPlatforms.backendLabel(platform);

  static bool isDobdaPlatform(String platform) =>
      LiveGoApiPlatforms.bySlug(platform).isDobda;

  static Future<List<String>> fetchCategoriesFor(String platform) async {
    return availableCategoriesFor(platform);
  }

  static Future<String> pingPlatform(String platform) async {
    return LiveGoApiManager.runStatus(
      platform: platform,
      operation: 'ping',
      timeout: ApiTimeoutPolicy.ping,
      request: () => LiveGoApiProviderRegistry.providerFor(platform).ping(languageFor(platform)),
      fallbackStatus: 'offline',
    );
  }

  static String label(String slug) {
    final config = LiveGoApiPlatforms.bySlugOrNull(slug);
    if (config != null) return config.name;
    return slug
        .split(RegExp(r'[_-]'))
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }
}
