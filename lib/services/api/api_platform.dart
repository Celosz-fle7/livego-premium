enum LiveGoVideoType {
  mp4,
  hls,
  encrypted,
}

class LiveGoApiPlatform {
  final String slug;
  final String name;
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
    this.enabledByDefault = false,
    this.supportsSubtitle = false,
    this.streamFromAllEpisodes = false,
  });

  bool get isEncrypted => videoType == LiveGoVideoType.encrypted;
  bool get isHls => videoType == LiveGoVideoType.hls;
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
      defaultLang: 'en',
      searchParam: 'q',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['en', 'id', 'th', 'vi', 'ja', 'ko'],
      enabledByDefault: true,
      categories: ['Trending', 'For You'],
    ),
    LiveGoApiPlatform(
      slug: 'dramabox',
      name: 'DramaBox',
      defaultLang: 'en',
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
      defaultLang: 'en',
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
  ];

  static List<String> get supportedSlugs => all.map((e) => e.slug).toList();

  static List<String> get defaultSlugs => all
      .where((e) => e.enabledByDefault)
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
    return null;
  }

  static String normalizeSlug(String platform) {
    return platform.trim().toLowerCase();
  }

  static String langFor(String platform, String requested) {
    final config = bySlug(platform);
    var clean = requested.trim().toLowerCase();
    if (clean.isEmpty) return config.defaultLang;

    // Aplikasi pakai kode Indonesia `id`, NetShort API pakai `in`.
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
