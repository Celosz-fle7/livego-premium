import '../../core/livego_settings.dart';
import '../../services/api/api_platform.dart';
import '../../services/livego_api_gateway.dart';
import '../api_manager/api_timeout_policy.dart';
import '../api_manager/api_provider_registry.dart';
import '../api_manager/livego_api_manager.dart';

class LiveGoCatalogPlatformService {
  const LiveGoCatalogPlatformService._();

  static final Map<String, List<String>> _categoryCache = <String, List<String>>{};

  static List<String> get platforms {
    final chosen = LiveGoSettings.homePlatforms.where(LiveGoSettings.isPlatformActive).toList(growable: false);
    if (chosen.isNotEmpty) return chosen;
    final active = LiveGoSettings.activePlatforms.toList(growable: false);
    return active.isEmpty ? LiveGoApiGateway.defaultPlatforms : active;
  }

  static List<String> get allPlatforms => LiveGoApiGateway.supportedPlatforms;

  static List<String> get platformLabels => platforms.map(label).toList();

  static List<String> labelsFor(List<String> values) => values.map(label).toList();

  static List<String> get categories => categoriesFor(platforms.isEmpty ? 'melolo' : platforms.first);

  static List<String> categoriesFor(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final cached = _categoryCache[config.slug];
    if (cached != null && cached.isNotEmpty) return cached.take(6).toList(growable: false);
    return LiveGoSettings.categoriesFor(config.slug).take(6).toList(growable: false);
  }

  static List<String> availableCategoriesFor(String platform) =>
      LiveGoApiPlatforms.categoriesFor(platform);

  static List<String> languagesFor(String platform) =>
      LiveGoApiPlatforms.languagesFor(platform);

  static String languageFor(String platform) =>
      LiveGoSettings.languageForPlatform(platform);

  static String backendLabel(String platform) =>
      LiveGoApiPlatforms.backendLabel(platform);

  static bool isDobdaPlatform(String platform) =>
      LiveGoApiPlatforms.bySlug(platform).isDobda;

  static Future<List<String>> fetchCategoriesFor(String platform) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final cached = _categoryCache[config.slug];
    if (cached != null && cached.isNotEmpty) return cached.take(6).toList(growable: false);

    try {
      final remote = await LiveGoApiGateway.categories(
        platform: config.slug,
        lang: languageFor(config.slug),
      );
      for (final entry in remote.entries) {
        final remoteConfig = LiveGoApiPlatforms.bySlugOrNull(entry.key);
        if (remoteConfig == null) continue;
        final normalized = LiveGoApiPlatforms.normalizeCategoriesFor(remoteConfig.slug, entry.value);
        if (normalized.isNotEmpty) {
          _categoryCache[remoteConfig.slug] = normalized.take(6).toList(growable: false);
          LiveGoSettings.setCategoriesFor(remoteConfig.slug, normalized);
        }
      }
      final selected = remote[config.slug] ?? remote[config.apiSlug] ?? remote['global'];
      if (selected != null && selected.isNotEmpty) {
        final normalized = LiveGoApiPlatforms.normalizeCategoriesFor(config.slug, selected);
        if (normalized.isNotEmpty) {
          _categoryCache[config.slug] = normalized.take(6).toList(growable: false);
          LiveGoSettings.setCategoriesFor(config.slug, normalized);
          return _categoryCache[config.slug]!;
        }
      }
    } catch (e) {
      print('LIVEGO CATEGORY FETCH FALLBACK ${config.slug}: $e');
    }

    final fallback = LiveGoApiPlatforms.categoriesFor(config.slug).take(6).toList(growable: false);
    _categoryCache[config.slug] = fallback;
    LiveGoSettings.setCategoriesFor(config.slug, fallback);
    return fallback;
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
