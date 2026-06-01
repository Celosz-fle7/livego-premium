import 'api_backend.dart';

enum LiveGoVideoType {
  mp4,
  hls,
  encrypted,
}

class LiveGoApiPlatform {
  final String slug;
  final String endpointSlug;
  final String name;
  final LiveGoApiBackend backend;
  final String defaultLang;
  final String searchParam;
  final LiveGoVideoType videoType;
  final List<String> supportedLangs;
  final bool enabledByDefault;
  final bool supportsSubtitle;
  final bool streamFromAllEpisodes;
  final List<String> categories;

  const LiveGoApiPlatform({
    required this.slug,
    required this.name,
    required this.defaultLang,
    required this.searchParam,
    required this.videoType,
    required this.supportedLangs,
    required this.categories,
    this.endpointSlug = '',
    this.backend = LiveGoApiBackend.anichin,
    this.enabledByDefault = false,
    this.supportsSubtitle = false,
    this.streamFromAllEpisodes = false,
  });

  String get apiSlug => endpointSlug.isEmpty ? slug : endpointSlug;
  bool get isEncrypted => videoType == LiveGoVideoType.encrypted;
  bool get isHls => videoType == LiveGoVideoType.hls;
  bool get isDobda => backend == LiveGoApiBackend.dobda;
}

class LiveGoApiPlatforms {
  static const List<LiveGoApiPlatform> all = [
    LiveGoApiPlatform(
      slug: 'shortmax',
      name: 'ShortMax',
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['id', 'en'],
      enabledByDefault: true,
      categories: ['Trending', 'For You'],
    ),
    LiveGoApiPlatform(
      slug: 'netshort',
      name: 'NetShort',
      defaultLang: 'in',
      searchParam: 'query',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['in', 'en', 'th', 'vi', 'ja', 'ko'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'For You'],
    ),
    LiveGoApiPlatform(
      slug: 'pinedrama',
      name: 'PineDrama',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['en', 'id', 'th', 'vi', 'ja', 'ko'],
      enabledByDefault: true,
      categories: ['Trending', 'For You'],
    ),
    LiveGoApiPlatform(
      slug: 'dramabox',
      name: 'DramaBox',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['en', 'id', 'ar', 'zh', 'de', 'fr', 'it', 'ja', 'ko', 'es', 'pt', 'th', 'tr', 'vi', 'ms', 'in'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: ['Trending', 'Latest', 'VIP', 'Dub Indo', 'For You'],
    ),
    LiveGoApiPlatform(
      slug: 'flickreels',
      name: 'FlickReels',
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['en', 'ar', 'zh', 'de', 'fr', 'id', 'it', 'ja', 'ko', 'es', 'pt', 'th', 'tr'],
      enabledByDefault: true,
      streamFromAllEpisodes: true,
      categories: ['Trending', 'For You'],
    ),
    LiveGoApiPlatform(
      slug: 'melolo',
      name: 'Melolo',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.encrypted,
      supportedLangs: ['id', 'en', 'ar', 'zh', 'de', 'fr', 'it', 'ja', 'ko', 'es', 'pt', 'th', 'tr', 'vi', 'ms', 'in'],
      categories: ['Trending', 'For You'],
    ),

    // Dobda API kedua. Slug internal diberi prefix supaya tidak bentrok dengan
    // platform Anichin yang namanya sama. endpointSlug adalah category_p Dobda.
    // Plan STARTER Dobda: 20 platform. Kategori Home hanya Home/Discover; Banner
    // dipakai sebagai banner source saja, bukan tab kategori grid.
    LiveGoApiPlatform(
      slug: 'dobda_melolo',
      endpointSlug: 'melolo',
      name: 'Melolo Dobda',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_pinedrama',
      endpointSlug: 'pinedrama',
      name: 'PineDrama Dobda',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_freereels',
      endpointSlug: 'freereels',
      name: 'FreeReels',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_meloshort',
      endpointSlug: 'meloshort',
      name: 'MeloShort',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_reelshort',
      endpointSlug: 'reelshort',
      name: 'ReelShort',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_reelife',
      endpointSlug: 'reelife',
      name: 'Reelife',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_dramawave',
      endpointSlug: 'dramawave',
      name: 'DramaWave',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_stardusttv',
      endpointSlug: 'stardusttv',
      name: 'StardustTV',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_netshort',
      endpointSlug: 'netshort',
      name: 'NetShort Dobda',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_goodshort',
      endpointSlug: 'goodshort',
      name: 'GoodShort',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_shortmax',
      endpointSlug: 'shortmax',
      name: 'ShortMax Dobda',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_flickreels',
      endpointSlug: 'flickreels',
      name: 'FlickReels Dobda',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_flextv',
      endpointSlug: 'flextv',
      name: 'FlexTV',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_dramarush',
      endpointSlug: 'dramarush',
      name: 'DramaRush',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_rapidtv',
      endpointSlug: 'rapidtv',
      name: 'RapidTV',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_dramanova',
      endpointSlug: 'dramanova',
      name: 'DramaNova',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_fundrama',
      endpointSlug: 'fundrama',
      name: 'FunDrama',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_starshort',
      endpointSlug: 'starshort',
      name: 'StarShort',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_dramapops',
      endpointSlug: 'dramapops',
      name: 'DramaPops',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_snackshort',
      endpointSlug: 'snackshort',
      name: 'SnackShort',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      supportsSubtitle: true,
      categories: ['Home', 'Discover'],
    ),
  ];

  static List<String> get supportedSlugs => all.map((e) => e.slug).toList();

  static List<String> get defaultSlugs => all
      .where((e) => e.enabledByDefault)
      .map((e) => e.slug)
      .toList();

  static List<String> slugsForBackend(LiveGoApiBackend backend) => all
      .where((e) => e.backend == backend)
      .map((e) => e.slug)
      .toList();

  static bool supports(String platform) => bySlugOrNull(platform) != null;

  static LiveGoApiPlatform bySlug(String platform) {
    return bySlugOrNull(platform) ?? all.first;
  }

  static LiveGoApiPlatform? bySlugOrNull(String platform) {
    final slug = normalizeSlug(platform);
    for (final item in all) {
      if (item.slug == slug) return item;
    }
    for (final item in all) {
      if (item.apiSlug == slug) return item;
    }
    return null;
  }

  static String normalizeSlug(String platform) {
    return platform.trim().toLowerCase();
  }

  static String endpointSlug(String platform) => bySlug(platform).apiSlug;

  static LiveGoApiBackend backendOf(String platform) => bySlug(platform).backend;

  static String backendLabel(String platform) => bySlug(platform).backend.label;

  static String labelFor(String platform) => bySlug(platform).name;

  static String langFor(String platform, String requested) {
    final config = bySlug(platform);
    var clean = requested.trim().toLowerCase();
    if (clean.isEmpty) return config.defaultLang;

    // Aplikasi pakai kode Indonesia `id`, NetShort Anichin API pakai `in`.
    if (config.slug == 'netshort' && clean == 'id') clean = 'in';
    if (config.slug != 'netshort' && clean == 'in' && config.supportedLangs.contains('id')) {
      clean = 'id';
    }

    if (config.supportedLangs.contains(clean)) return clean;
    return config.defaultLang;
  }

  static List<String> languagesFor(String platform) {
    return List<String>.from(bySlug(platform).supportedLangs);
  }

  static List<String> categoriesFor(String platform) {
    return List<String>.from(bySlug(platform).categories);
  }
}
