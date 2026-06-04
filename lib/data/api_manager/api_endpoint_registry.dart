import '../../services/api/api_backend.dart';
import '../../services/api/api_platform.dart';
import 'api_provider_contract.dart';
import 'api_provider_registry.dart';

class ApiEndpointRegistry {
  const ApiEndpointRegistry._();

  static String endpointSlugFor(String platform) {
    return LiveGoApiPlatforms.endpointSlug(platform);
  }

  static String backendFor(String platform) {
    return LiveGoApiPlatforms.backendLabel(platform);
  }

  static bool supports(String platform, ApiProviderFeature feature) {
    return LiveGoApiProviderRegistry.supports(platform, feature);
  }

  static String featureSummaryFor(String platform) {
    final badges = LiveGoApiProviderRegistry.capabilityBadgesFor(platform);
    if (badges.isEmpty) return 'STD';
    return badges.join(' • ');
  }

  static Map<String, Object> describe(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final capability = LiveGoApiProviderRegistry.capabilityFor(platform);
    return <String, Object>{
      'slug': config.slug,
      'endpointSlug': config.apiSlug,
      'name': config.name,
      'backend': config.backend.label,
      'defaultLang': config.defaultLang,
      'languages': config.supportedLangs,
      'categories': config.categories,
      'subtitle': capability.subtitle,
      'audio': capability.audio,
      'encryptedVideo': capability.encryptedVideo,
      'streamFromAllEpisodes': capability.streamFromAllEpisodes,
    };
  }
}
