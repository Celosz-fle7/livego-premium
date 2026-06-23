import 'api_platform.dart';

class ApiEndpoints {
  const ApiEndpoints._();

  static String categories(String platform) => '/api/v2/categories';

  static String home(String platform) => '/api/v2/home';

  static String discover(String platform) => '/api/v2/discover';

  static String banner(String platform) => '/api/v2/banner';

  static String search(String platform) => '/api/v2/search';

  static String detail(String platform) => '/api/v2/detail';

  static String video(String platform) => '/api/v2/video';

  static Map<String, String> platformQuery(String platform, {String lang = 'id'}) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    return <String, String>{
      'category_p': config.apiSlug,
      'lang': LiveGoApiPlatforms.langFor(config.slug, lang),
    };
  }

  static String collection(String platform, String key) {
    final clean = key.toLowerCase().replaceAll(' ', '');
    if (clean == 'latest' || clean == 'terbaru' || clean == 'discover') {
      return discover(platform);
    }
    return home(platform);
  }
}
