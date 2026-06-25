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
      slug: 'freereels',
      endpointSlug: 'freereels',
      name: 'FreeReels',
      backend: LiveGoApiBackend.nobuzero,
      defaultLang: 'id',
      searchParam: 'q',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id'],
      enabledByDefault: true,
      supportsSubtitle: true,
      streamFromAllEpisodes: true,
      categories: ['Trending', 'Terbaru', 'Populer', 'Completed'],
    ),
  ];

  static const List<String> tvStarterSlugs = <String>['freereels'];

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

  static String normalizeSlug(String platform) =>
      platform.trim().toLowerCase();

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
