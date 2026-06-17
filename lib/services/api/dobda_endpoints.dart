class DobdaEndpoints {
  const DobdaEndpoints._();

  static const languages = '/api/v2/languages';
  static const categories = '/api/v2/categories';
  static const home = '/api/v2/home';
  static const discover = '/api/v2/discover';
  static const banner = '/api/v2/banner';
  static const detail = '/api/v2/detail';
  static const video = '/api/v2/video';
  static const search = '/api/v2/search';
  static const keyStatus = '/api/v2/key/status';

  static Map<String, String> homeQuery({
    required String categorySlug,
    String lang = 'id',
  }) =>
      <String, String>{
        'category_p': categorySlug,
        'lang': lang,
      };

  static Map<String, String> discoverQuery({
    required String categorySlug,
    String lang = 'id',
    int page = 1,
  }) =>
      <String, String>{
        'category_p': categorySlug,
        'lang': lang,
        'sort': 'desc',
        'page': '$page',
      };

  static Map<String, String> bannerQuery({
    required String categorySlug,
    String lang = 'id',
  }) =>
      <String, String>{
        'category_p': categorySlug,
        'lang': lang,
      };

  static Map<String, String> searchQuery({
    required String query,
    required String categorySlug,
    String lang = 'id',
    int page = 1,
  }) =>
      <String, String>{
        'q': query,
        'category_p': categorySlug,
        'lang': lang,
        'page': '$page',
      };

  static Map<String, String> detailQuery({
    required String id,
    required String categorySlug,
    String lang = 'id',
  }) =>
      <String, String>{
        'id': id,
        'category_p': categorySlug,
        'lang': lang,
      };

  static Map<String, String> videoQuery({
    required String id,
    required String categorySlug,
    required String chapterId,
    String lang = 'id',
  }) =>
      <String, String>{
        'id': id,
        'category_p': categorySlug,
        'chapterId': chapterId,
        'lang': lang,
      };
}
