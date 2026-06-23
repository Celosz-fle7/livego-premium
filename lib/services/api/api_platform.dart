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
    this.backend = LiveGoApiBackend.nobuzero,
    this.enabledByDefault = false,
    this.supportsSubtitle = false,
    this.streamFromAllEpisodes = false,
  });

  String get apiSlug => endpointSlug.isEmpty ? slug : endpointSlug;
  bool get isEncrypted => videoType == LiveGoVideoType.encrypted;
  bool get isHls => videoType == LiveGoVideoType.hls;
  bool get isDobda => backend == LiveGoApiBackend.nobuzero;
  bool get isNobuzero => backend == LiveGoApiBackend.nobuzero;
}

class LiveGoApiPlatforms {
  static const List<LiveGoApiPlatform> all = [
    LiveGoApiPlatform(
      slug: 'melolo',
      endpointSlug: 'melolo',
      name: 'Melolo',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Populer', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'dramabox',
      endpointSlug: 'dramabox',
      name: 'Dramabox',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Populer', 'Completed'],
    ),
    LiveGoApiPlatform(
      slug: 'moviebox',
      endpointSlug: 'moviebox',
      name: 'Moviebox',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Movie', 'Series'],
    ),
    LiveGoApiPlatform(
      slug: 'mydrama',
      endpointSlug: 'mydrama',
      name: 'Mydrama',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Romance', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'dramanova',
      endpointSlug: 'dramanova',
      name: 'Dramanova',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Romance', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'shorten',
      endpointSlug: 'shorten',
      name: 'Shorten',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'dramahub',
      endpointSlug: 'dramahub',
      name: 'Dramahub',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Drama', 'Romance'],
    ),
    LiveGoApiPlatform(
      slug: 'flickshort',
      endpointSlug: 'flickshort',
      name: 'Flickshort',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'loklok',
      endpointSlug: 'loklok',
      name: 'Loklok',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Movie', 'Series'],
    ),
    LiveGoApiPlatform(
      slug: 'radreel',
      endpointSlug: 'radreel',
      name: 'Radreel',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'reelflix',
      endpointSlug: 'reelflix',
      name: 'Reelflix',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'shortflix',
      endpointSlug: 'shortflix',
      name: 'Shortflix',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'viu',
      endpointSlug: 'viu',
      name: 'Viu',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Drama', 'Series'],
    ),
    LiveGoApiPlatform(
      slug: 'dotdrama',
      endpointSlug: 'dotdrama',
      name: 'Dotdrama',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Drama', 'Romance'],
    ),
    LiveGoApiPlatform(
      slug: 'dramarush',
      endpointSlug: 'dramarush',
      name: 'Dramarush',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Drama', 'Romance'],
    ),
    LiveGoApiPlatform(
      slug: 'layarkaca',
      endpointSlug: 'layarkaca',
      name: 'Layarkaca',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Movie', 'Series'],
    ),
    LiveGoApiPlatform(
      slug: 'netshort',
      endpointSlug: 'netshort',
      name: 'Netshort',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'shortreels',
      endpointSlug: 'shortreels',
      name: 'Shortreels',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'bittv',
      endpointSlug: 'bittv',
      name: 'Bittv',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Movie', 'Series'],
    ),
    LiveGoApiPlatform(
      slug: 'fizzo',
      endpointSlug: 'fizzo',
      name: 'Fizzo',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Drama', 'Romance'],
    ),
    LiveGoApiPlatform(
      slug: 'shortmax',
      endpointSlug: 'shortmax',
      name: 'Shortmax',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'freereels',
      endpointSlug: 'freereels',
      name: 'Freereels',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Short', 'Drama'],
    ),
    LiveGoApiPlatform(
      slug: 'dramawave',
      endpointSlug: 'dramawave',
      name: 'Dramawave',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Trending', 'Terbaru', 'Drama', 'Romance'],
    ),

  ];

  /// TV starter pack yang diexpose ke Home/Source Manager.
  ///
  /// Anichin-style source disimpan sebagai legacy/off. Yang ON hanya Nobuzero clean
  /// starter supaya Home tidak campur antara engine Anichin dan engine Nobuzero.
  static const List<String> tvStarterSlugs = <String>[
    'freereels',
    'melolo',
    'dramabox',
    'moviebox',
    'mydrama',
    'dramanova',
    'shorten',
    'dramahub',
    'flickshort',
    'loklok',
    'radreel',
    'reelflix',
    'shortflix',
    'viu',
    'dotdrama',
    'dramarush',
    'layarkaca',
    'netshort',
    'shortreels',
    'bittv',
    'fizzo',
    'shortmax',
    'dramawave',
  ];

  static List<String> get supportedSlugs => List<String>.unmodifiable(tvStarterSlugs);

  static List<String> get defaultSlugs => List<String>.unmodifiable(tvStarterSlugs);

  static List<String> get allKnownSlugs => all
      .map((e) => e.slug)
      .toList();

  static List<String> slugsForBackend(LiveGoApiBackend backend) => all
      .where((e) => e.backend == backend)
      .map((e) => e.slug)
      .toList();

  static bool supports(String platform) {
    final slug = normalizeSlug(platform);
    if (supportedSlugs.contains(slug)) return true;
    for (final item in all) {
      if (item.apiSlug == slug && supportedSlugs.contains(item.slug)) return true;
    }
    return false;
  }

  static LiveGoApiPlatform bySlug(String platform) {
    return bySlugOrNull(platform) ??
        all.firstWhere(
          (item) => item.slug == tvStarterSlugs.first,
          orElse: () => all.first,
        );
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

    // Legacy NetShort alias `in` tetap dinormalisasi hanya jika source itu diaktifkan lagi.
    if (config.apiSlug == 'netshort' && clean == 'id') clean = 'in';
    if (config.apiSlug != 'netshort' && clean == 'in' && config.supportedLangs.contains('id')) {
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

  static String categoryKey(String platform, String category) {
    final clean = category.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    const aliases = <String, String>{
      '': 'home',
      'home': 'home',
      'beranda': 'home',
      'trending': 'trending',
      'populer': 'trending',
      'popular': 'trending',
      'foryou': 'foryou',
      'untukkamu': 'foryou',
      'rekomendasi': 'foryou',
      'latest': 'latest',
      'terbaru': 'latest',
      'update': 'latest',
      'completed': 'latest',
      'vip': 'vip',
      'dubindo': 'dubindo',
      'dubbing': 'livego',
      'dub': 'livego',
      'sulih': 'livego',
      'sulihsuara': 'livego',
      'livego': 'livego',
      'indonesia': 'livego',
      'indo': 'livego',
      'indonesiafeed': 'livego',
      'dubindonesia': 'livego',
      'discover': 'discover',
      'jelajah': 'discover',
      'movie': 'movie',
      'film': 'movie',
      'series': 'series',
      'drama': 'drama',
      'romance': 'romance',
      'romantis': 'romance',
      'short': 'short',
      'pendek': 'short',
    };
    return aliases[clean] ?? clean;
  }

  static String categoryLabel(String platform, String category) {
    final config = bySlug(platform);
    final key = categoryKey(config.slug, category);
    switch (key) {
      case 'trending':
        return 'Trending';
      case 'latest':
        return 'Terbaru';
      case 'livego':
        return 'LiveGo';
      case 'movie':
        return 'Movie';
      case 'series':
        return 'Series';
      case 'drama':
        return 'Drama';
      case 'romance':
        return 'Romance';
      case 'short':
        return 'Short';
      case 'foryou':
        return 'Untuk Kamu';
      case 'vip':
        return 'VIP';
      case 'dubindo':
        return 'Dub Indo';
      case 'home':
        return config.isNobuzero ? 'Trending' : 'Beranda';
      case 'discover':
        return config.isNobuzero ? 'Terbaru' : 'Jelajah';
    }
    return category.trim().isEmpty ? (config.isNobuzero ? 'Trending' : 'Populer') : category.trim();
  }

  static List<String> normalizeCategoriesFor(String platform, Iterable<String> values) {
    final config = bySlug(platform);
    final available = categoriesFor(config.slug);
    final result = <String>[];
    final seenKeys = <String>{};
    for (final raw in values) {
      final label = raw.trim();
      if (label.isEmpty) continue;
      final key = categoryKey(config.slug, label);
      if (seenKeys.add(key)) result.add(label);
    }
    if (result.isEmpty) result.addAll(available.take(2));
    return result.take(4).toList();
  }

}
