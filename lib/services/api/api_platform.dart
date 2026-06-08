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
    this.backend = LiveGoApiBackend.dobda,
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
    // DOBDA FAMILY = ON / active.
    // ANICHIN FAMILY = OFF / reserved, tidak masuk Home/Source Manager.
    // Nama platform bisa mirip, tapi registry aktif di bawah ini murni Dobda clean starter.
    LiveGoApiPlatform(
      slug: 'dobda_freereels',
      endpointSlug: 'freereels',
      name: 'FreeReels',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Home', 'LiveGo'],
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
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Home', 'LiveGo'],
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
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Home', 'LiveGo'],
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
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Home', 'LiveGo'],
    ),
    LiveGoApiPlatform(
      slug: 'dobda_reelife',
      endpointSlug: 'reelife',
      name: 'ReelLife',
      backend: LiveGoApiBackend.dobda,
      defaultLang: 'id',
      searchParam: 'query',
      videoType: LiveGoVideoType.hls,
      supportedLangs: ['id', 'en', 'ja', 'ko', 'th', 'ar', 'pt', 'es', 'vi', 'de', 'fr', 'it', 'tr'],
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Home', 'LiveGo'],
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
      enabledByDefault: true,
      supportsSubtitle: true,
      categories: ['Home', 'LiveGo'],
    ),

  ];

  /// TV starter pack yang diexpose ke Home/Source Manager.
  ///
  /// Anichin-style source disimpan sebagai legacy/off. Yang ON hanya Dobda clean
  /// starter supaya Home tidak campur antara engine Anichin dan engine Dobda.
  static const List<String> tvStarterSlugs = <String>[
    'dobda_freereels',
    'dobda_goodshort',
    'dobda_dramawave',
    'dobda_reelshort',
    'dobda_reelife',
    'dobda_rapidtv',
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
    };
    return aliases[clean] ?? clean;
  }

  static String categoryLabel(String platform, String category) {
    final config = bySlug(platform);
    final key = categoryKey(config.slug, category);
    if (config.isDobda) {
      if (key == 'livego' || key == 'indonesia' || key == 'dubindo') return 'LiveGo';
      return 'Home';
    }
    switch (key) {
      case 'trending':
        return 'Populer';
      case 'foryou':
        return 'Untuk Kamu';
      case 'latest':
        return 'Terbaru';
      case 'vip':
        return 'VIP';
      case 'dubindo':
        return 'Dub Indo';
      case 'home':
        return 'Beranda';
      case 'discover':
        return 'Jelajah';
    }
    return category.trim().isEmpty ? (config.isDobda ? 'Beranda' : 'Populer') : category.trim();
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
    if (result.isEmpty) result.addAll(available.take(2));
    return result.take(6).toList();
  }

}
