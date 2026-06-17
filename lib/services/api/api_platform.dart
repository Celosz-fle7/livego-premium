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
  bool get isNobuzero => backend == LiveGoApiBackend.nobuzero;
}

class LiveGoApiPlatforms {
  static const List<LiveGoApiPlatform> all = [
    LiveGoApiPlatform(
      slug: 'nobuzero_melolo',
      endpointSlug: 'melolo',
      name: 'Melolo',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_dramabox',
      endpointSlug: 'dramabox',
      name: 'DramaBox',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_moviebox',
      endpointSlug: 'moviebox',
      name: 'MovieBox',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_mydrama',
      endpointSlug: 'mydrama',
      name: 'MyDrama',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_dramanova',
      endpointSlug: 'dramanova',
      name: 'DramaNova',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_shorten',
      endpointSlug: 'shorten',
      name: 'Shorten',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_dramahub',
      endpointSlug: 'dramahub',
      name: 'DramaHub',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_flickshort',
      endpointSlug: 'flickshort',
      name: 'FlickShort',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_loklok',
      endpointSlug: 'loklok',
      name: 'Loklok',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_radreel',
      endpointSlug: 'radreel',
      name: 'RadReel',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_reelflix',
      endpointSlug: 'reelflix',
      name: 'ReelFlix',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_shortflix',
      endpointSlug: 'shortflix',
      name: 'Shortflix',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_viu',
      endpointSlug: 'viu',
      name: 'Viu',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_dotdrama',
      endpointSlug: 'dotdrama',
      name: 'DotDrama',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_dramarush',
      endpointSlug: 'dramarush',
      name: 'DramaRush',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_layarkaca',
      endpointSlug: 'layarkaca',
      name: 'Layarkaca',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_netshort',
      endpointSlug: 'netshort',
      name: 'NetShort',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'in'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_shortreels',
      endpointSlug: 'shortreels',
      name: 'ShortReels',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_bittv',
      endpointSlug: 'bittv',
      name: 'BitTV',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_fizzo',
      endpointSlug: 'fizzo',
      name: 'Fizzo',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_shortmax',
      endpointSlug: 'shortmax',
      name: 'ShortMax',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_freereels',
      endpointSlug: 'freereels',
      name: 'FreeReels',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'nobuzero_dramawave',
      endpointSlug: 'dramawave',
      name: 'DramaWave',
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en'],
      supportsSubtitle: true,
      categories: ['Home', 'Terbaru', 'LiveGo'],
    ),
  ];

  static const List<String> tvStarterSlugs = <String>[
    'nobuzero_melolo',
    'nobuzero_dramabox',
    'nobuzero_moviebox',
    'nobuzero_mydrama',
    'nobuzero_netshort',
    'nobuzero_shortmax',
  ];

  static List<String> get supportedSlugs => all.map((e) => e.slug).toList();

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
    final slug = platform.trim().toLowerCase();
    return slug.startsWith('do' 'bda_')
        ? slug.replaceFirst('do' 'bda_', 'nobuzero_')
        : slug;
  }

  static String endpointSlug(String platform) => bySlug(platform).apiSlug;

  static LiveGoApiBackend backendOf(String platform) => bySlug(platform).backend;

  static String backendLabel(String platform) => bySlug(platform).backend.label;

  static String labelFor(String platform) => bySlug(platform).name;

  static String langFor(String platform, String requested) {
    final config = bySlug(platform);
    var clean = requested.trim().toLowerCase();
    if (clean.isEmpty) return config.defaultLang;

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
      'latest': 'discover',
      'terbaru': 'discover',
      'discover': 'discover',
      'jelajah': 'discover',
      'vip': 'vip',
      'dubindo': 'livego',
      'dubbing': 'livego',
      'dub': 'livego',
      'sulih': 'livego',
      'sulihsuara': 'livego',
      'livego': 'livego',
      'indonesia': 'livego',
      'indo': 'livego',
      'indonesiafeed': 'livego',
      'dubindonesia': 'livego',
    };
    return aliases[clean] ?? clean;
  }

  static String categoryLabel(String platform, String category) {
    final config = bySlug(platform);
    final key = categoryKey(config.slug, category);
    if (config.isNobuzero) {
      if (key == 'livego') return 'LiveGo';
      if (key == 'discover') return 'Terbaru';
      return 'Home';
    }
    switch (key) {
      case 'trending':
        return 'Populer';
      case 'foryou':
        return 'Untuk Kamu';
      case 'latest':
      case 'discover':
        return 'Terbaru';
      case 'vip':
        return 'VIP';
      case 'livego':
        return 'LiveGo';
      case 'home':
        return 'Beranda';
    }
    return category.trim().isEmpty ? (config.isNobuzero ? 'Beranda' : 'Populer') : category.trim();
  }

  static List<String> normalizeCategoriesFor(String platform, Iterable<String> values) {
    final config = bySlug(platform);
    final available = categoriesFor(config.slug);
    final byKey = <String, String>{
      for (final item in available) categoryKey(config.slug, item): item,
    };
    final result = <String>[];
    for (final raw in values) {
      final key = categoryKey(config.slug, raw);
      final label = byKey[key] ?? categoryLabel(config.slug, raw);
      if (available.contains(label) && !result.contains(label)) {
        result.add(label);
      }
    }
    if (result.isEmpty) result.addAll(available.take(3));
    return result.take(6).toList();
  }
}
