import 'api_platform.dart';

class ApiEndpoints {
  static String languages(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/languages';
  }

  static String trending(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/trending';
  }

  static String latest(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/latest';
  }

  static String forYou(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    if (slug == 'melolo') return trending(slug);
    return '/api/$slug/foryou';
  }

  static String vip(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/vip';
  }

  static String dubIndo(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/dubindo';
  }

  static String search(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/search';
  }

  static String detail(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/detail';
  }

  static String allEpisode(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/allepisode';
  }

  static String episode(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/episode';
  }

  static String subtitles(String platform) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    return '/api/$slug/subtitles';
  }

  static String collection(String platform, String key) {
    final slug = LiveGoApiPlatforms.normalizeSlug(platform);
    final clean = key.toLowerCase().replaceAll(' ', '');

    if (clean == 'foryou') return forYou(slug);
    if (clean == 'latest' && slug == 'dramabox') return latest(slug);
    if (clean == 'vip' && slug == 'dramabox') return vip(slug);
    if ((clean == 'dubindo' || clean == 'dubindonesia') && slug == 'dramabox') {
      return dubIndo(slug);
    }

    return trending(slug);
  }
}
