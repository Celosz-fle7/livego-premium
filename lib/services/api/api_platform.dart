import 'api_backend.dart';

enum LiveGoVideoType {
  mp4,
  hls,
  encrypted,
  cenc,
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
    this.backend = LiveGoApiBackend.direct,
    this.enabledByDefault = false,
    this.supportsSubtitle = false,
    this.streamFromAllEpisodes = false,
  });

  String get apiSlug => endpointSlug.isEmpty ? slug : endpointSlug;
  bool get isEncrypted => videoType == LiveGoVideoType.encrypted;
  bool get isHls => videoType == LiveGoVideoType.hls;
  bool get isDobda => false;
  bool get isNobuzero => false;
}

class LiveGoApiPlatforms {
  static const List<LiveGoApiPlatform> all = [
    LiveGoApiPlatform(
      slug: 'freereels',
      endpointSlug: 'freereels',
      name: 'FreeReels',
      backend: LiveGoApiBackend.direct,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: ['Trending', 'Terbaru', 'Populer', 'Completed'],
    ),
    LiveGoApiPlatform(
      slug: 'melolo',
      endpointSlug: 'melolo',
      name: 'Melolo',
      backend: LiveGoApiBackend.direct,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: [
        'Romance',
        'Billionaire',
        'Rebirth',
        'Male Lead',
        'Counterattack',
        'Fantasy',
        'Love After Marriage',
        'Paranormal',
        'Mystery',
        'Teen Fic',
        'Modern Love',
        'CEO',
      ],
    ),
    LiveGoApiPlatform(
      slug: 'cinemaid',
      endpointSlug: 'cinemaid',
      name: 'CinemaID',
      backend: LiveGoApiBackend.direct,
      defaultLang: 'id',
      searchParam: 'keyword',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: [
        'Netflix',
        'Amazon Prime',
        'Apple TV+',
        'Disney+ Hotstar',
        'Vidio',
        'Vivamax',
        'Viu',
        'iFlix',
        'Crunchyroll',
        '18+',
      ],
    ),
    LiveGoApiPlatform(
      slug: 'shorttv',
      endpointSlug: 'shorttv',
      name: 'ShortTV',
      backend: LiveGoApiBackend.direct,
      defaultLang: 'id',
      searchParam: 'keyword',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'es', 'th', 'vi', 'pt'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: [
        'Semua',
        'Trending Indonesia',
        'Global / English',
        'Jepang',
        'Spanyol',
        'Thailand',
        'Vietnam',
        'Portugis',
      ],
    ),
    LiveGoApiPlatform(
      slug: 'moviebox',
      endpointSlug: 'moviebox',
      name: 'MovieBox',
      backend: LiveGoApiBackend.direct,
      defaultLang: 'id',
      searchParam: 'keyword',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['id', 'en'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: [
        'Sedang Trending',
        'Terbaru',
        'Balas Dendam',
        'Cerita Barat',
        'Drama Dubbing',
        'Lokal Short TV',
        'Animasi',
        '🔥Hot Short TV',
        'Trending Drama🔥',
        'Trending Indonesian Drama💗',
        'Trending Indonesian Movies',
        'Trending Movies',
        'K-Drama: New Release',
        'Indonesian Horror Stories 💀',
        'Free Now 🎉',
        'Into Animeverse🌟',
        'Thai-Drama',
        'Trending Indo Dubbed',
        'Action & Crime 👊',
        '100% LOVE 💗',
        'Family Time🏡',
      ],
    ),
    LiveGoApiPlatform(
      slug: 'netshort',
      endpointSlug: 'netshort',
      name: 'NetShort',
      backend: LiveGoApiBackend.direct,
      defaultLang: 'id',
      searchParam: 'keyword',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: [
        'Populer',
        'Trending',
        'Rilis Baru',
        'Kepuasan',
        'Sang Juara Kembali',
        'Bangkit Kembali',
        'Menghukum Penjahat',
        'Pertumbuhan Wanita',
        'Romantis Perkotaan',
      ],
    ),
    LiveGoApiPlatform(
      slug: 'shortdrama',
      endpointSlug: 'shortdrama',
      name: 'ShortDrama',
      backend: LiveGoApiBackend.direct,
      defaultLang: 'id',
      searchParam: 'kw',
      videoType: LiveGoVideoType.mp4,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: false,
      streamFromAllEpisodes: true,
      categories: [
        'Populer',
        'Rilis Baru',
        'Sulih Suara',
        'Peringkat',
        'Kategori',
        'Wanita',
        'Pria',
      ],
    ),
  ];

  static const List<String> tvStarterSlugs = <String>[
    'freereels',
    'cinemaid',
    'melolo',
    'shorttv',
    'moviebox',
    'netshort',
    'shortdrama',
  ];

  static List<String> get supportedSlugs =>
      List<String>.unmodifiable(tvStarterSlugs);

  static List<String> get defaultSlugs =>
      List<String>.unmodifiable(tvStarterSlugs);

  static List<String> get allKnownSlugs =>
      all.map((e) => e.slug).toList();

  static List<String> slugsForBackend(LiveGoApiBackend backend) =>
      all.where((e) => e.backend == backend).map((e) => e.slug).toList();

  static bool supports(String platform) {
    final slug = normalizeSlug(platform);
    if (supportedSlugs.contains(slug)) return true;
    for (final item in all) {
      if (item.apiSlug == slug && supportedSlugs.contains(item.slug)) {
        return true;
      }
    }
    return false;
  }

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
    final clean = platform.trim().toLowerCase();
    if (clean == 'shortmax') return 'shorttv';
    return clean;
  }

  static String endpointSlug(String platform) => bySlug(platform).apiSlug;

  static LiveGoApiBackend backendOf(String platform) =>
      bySlug(platform).backend;

  static String backendLabel(String platform) =>
      bySlug(platform).backend.label;

  static String labelFor(String platform) => bySlug(platform).name;

  static String langFor(String platform, String requested) {
    final config = bySlug(platform);
    final clean = requested.trim().toLowerCase();
    if (clean.isEmpty) return config.defaultLang;
    if (config.supportedLangs.contains(clean)) return clean;
    return config.defaultLang;
  }

  static List<String> languagesFor(String platform) =>
      List<String>.from(bySlug(platform).supportedLangs);

  static List<String> categoriesFor(String platform) =>
      List<String>.from(bySlug(platform).categories);

  static String categoryKey(String platform, String category) {
    final clean =
        category.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    const aliases = <String, String>{
      '': 'home',
      'home': 'home',
      'beranda': 'home',
      'trending': 'trending',
      'populer': 'trending',
      'popular': 'trending',
      'latest': 'latest',
      'terbaru': 'latest',
      'completed': 'latest',
      'discover': 'discover',
      'jelajah': 'discover',
      'drama': 'drama',
      'romance': 'romance',
      'short': 'short',
    };
    return aliases[clean] ?? clean;
  }

  static String categoryLabel(String platform, String category) {
    final key = categoryKey(platform, category);
    switch (key) {
      case 'trending': return 'Trending';
      case 'latest':   return 'Terbaru';
      case 'drama':    return 'Drama';
      case 'romance':  return 'Romance';
      case 'short':    return 'Short';
      case 'home':     return 'Trending';
      case 'discover': return 'Terbaru';
    }
    return category.trim().isEmpty ? 'Trending' : category.trim();
  }

  static List<String> normalizeCategoriesFor(
      String platform, Iterable<String> values) {
    final result = <String>[];
    final seenKeys = <String>{};
    for (final raw in values) {
      final label = raw.trim();
      if (label.isEmpty) continue;
      final key = categoryKey(platform, label);
      if (seenKeys.add(key)) result.add(label);
    }
    if (result.isEmpty) result.addAll(categoriesFor(platform).take(2));
    return result.take(4).toList();
  }
}
