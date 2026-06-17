import '../../core/livego_settings.dart';
import '../../services/livego_api_gateway.dart';
import 'livego_api_manager.dart';

class ApiPlatformFallbackRouter {
  const ApiPlatformFallbackRouter._();

  static List<String> candidates(
    String preferred, {
    int max = 4,
    bool includeCooldownLast = true,
  }) {
    final cleanPreferred = _normalize(preferred);
    final ordered = <String>[];
    final seen = <String>{};

    void add(String slug) {
      final clean = _normalize(slug);
      if (clean.isEmpty) return;
      if (!LiveGoApiGateway.supports(clean)) return;
      if (seen.add(clean)) ordered.add(clean);
    }

    add(cleanPreferred);

    for (final slug in LiveGoSettings.homePlatforms) {
      if (LiveGoSettings.isPlatformActive(slug) && !LiveGoApiManager.isInCooldown(slug)) {
        add(slug);
      }
    }

    for (final slug in LiveGoSettings.activePlatforms) {
      if (!LiveGoApiManager.isInCooldown(slug)) add(slug);
    }

    for (final slug in LiveGoApiGateway.defaultPlatforms) {
      if (!LiveGoApiManager.isInCooldown(slug)) add(slug);
    }

    if (includeCooldownLast) {
      for (final slug in LiveGoSettings.activePlatforms) {
        add(slug);
      }
      for (final slug in LiveGoApiGateway.defaultPlatforms) {
        add(slug);
      }
    }

    return ordered.take(max).toList(growable: false);
  }

  static List<String> fallbackOnly(String preferred, {int max = 3}) {
    final cleanPreferred = _normalize(preferred);
    return candidates(preferred, max: max + 1)
        .where((slug) => slug != cleanPreferred)
        .take(max)
        .toList(growable: false);
  }

  static String _normalize(String value) {
    final clean = value.trim().toLowerCase();
    return clean.isEmpty ? 'dobda_freereels' : clean;
  }
}
