import '../services/api/api_platform.dart';

class LiveGoSettings {
  static const appName = 'LiveGo';

  static String language = 'id';
  static String defaultPlatform = 'shortmax';
  static String quality = 'Auto';
  static String layoutMode = 'Auto';
  static String drmMode = 'Auto';
  static bool subtitlesEnabled = true;
  static bool autoNextEnabled = true;
  static bool downloadWifiOnly = true;
  static bool lowEndTvMode = true;
  static bool backgroundPoster = true;
  static bool cachePlayback = true;
  static bool manualRotateButton = true;
  static int mobileHomeGrid = 3;
  static int tvHomeGrid = 6;
  static final Map<String, int> tvLastHomeCategories = <String, int>{};

  static final List<String> defaultPlatforms = LiveGoApiPlatforms.defaultSlugs;

  static final List<String> supportedPlatforms = LiveGoApiPlatforms.supportedSlugs;

  static final Set<String> activePlatforms = defaultPlatforms.toSet();
  static final List<String> homePlatforms = List<String>.from(defaultPlatforms);

  static final Map<String, String> platformLanguages = {
    for (final platform in LiveGoApiPlatforms.all)
      platform.slug: platform.defaultLang,
  };

  static final Map<String, List<String>> homeCategories = {
    for (final platform in LiveGoApiPlatforms.all)
      platform.slug: List<String>.from(platform.categories),
  };

  // unknown, online, slow, offline. Disimpan selama sesi aplikasi berjalan.
  static final Map<String, String> platformStatus = {
    for (final platform in supportedPlatforms) platform: 'unknown',
  };

  static bool isPlatformActive(String slug) => activePlatforms.contains(slug);

  static void togglePlatform(String slug) {
    if (activePlatforms.contains(slug)) {
      if (activePlatforms.length > 1) activePlatforms.remove(slug);
      homePlatforms.remove(slug);
    } else {
      activePlatforms.add(slug);
      if (homePlatforms.length < 6) homePlatforms.add(slug);
    }
    if (!activePlatforms.contains(defaultPlatform)) {
      defaultPlatform = activePlatforms.first;
    }
    if (homePlatforms.isEmpty) homePlatforms.add(defaultPlatform);
  }

  static bool isHomePlatform(String slug) => homePlatforms.contains(slug);

  static void toggleHomePlatform(String slug) {
    if (homePlatforms.contains(slug)) {
      if (homePlatforms.length > 1) homePlatforms.remove(slug);
    } else {
      if (homePlatforms.length < 6) {
        homePlatforms.add(slug);
        activePlatforms.add(slug);
      }
    }
    if (homePlatforms.isNotEmpty) defaultPlatform = homePlatforms.first;
  }

  static String languageForPlatform(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final saved = platformLanguages[config.slug] ?? config.defaultLang;
    return LiveGoApiPlatforms.langFor(config.slug, saved);
  }

  static void setLanguageForPlatform(String platform, String value) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    platformLanguages[config.slug] = LiveGoApiPlatforms.langFor(config.slug, value);
  }

  static List<String> categoriesFor(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final saved = homeCategories[config.slug] ?? config.categories;
    return LiveGoApiPlatforms.normalizeCategoriesFor(config.slug, saved);
  }

  static void setCategoriesFor(String platform, List<String> values) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    homeCategories[config.slug] = LiveGoApiPlatforms.normalizeCategoriesFor(config.slug, values);
  }

  static void setPlatformStatus(String slug, String status) {
    platformStatus[slug] = status;
  }

  static String statusFor(String slug) => platformStatus[slug] ?? 'unknown';


  static void setMobileHomeGrid(int value) {
    mobileHomeGrid = value.clamp(2, 6);
  }

  static void setTvHomeGrid(int value) {
    tvHomeGrid = value.clamp(4, 10);
  }

  static void reset() {
    language = 'id';
    defaultPlatform = 'shortmax';
    quality = 'Auto';
    layoutMode = 'Auto';
    drmMode = 'Auto';
    subtitlesEnabled = true;
    autoNextEnabled = true;
    downloadWifiOnly = true;
    lowEndTvMode = true;
    backgroundPoster = true;
    cachePlayback = true;
    manualRotateButton = true;
    mobileHomeGrid = 3;
    tvHomeGrid = 6;
    tvLastHomeCategories.clear();
    activePlatforms
      ..clear()
      ..addAll(defaultPlatforms);
    homePlatforms
      ..clear()
      ..addAll(defaultPlatforms);
    platformLanguages
      ..clear()
      ..addAll({
        for (final platform in LiveGoApiPlatforms.all)
          platform.slug: platform.defaultLang,
      });
    homeCategories
      ..clear()
      ..addAll({
        for (final platform in LiveGoApiPlatforms.all)
          platform.slug: List<String>.from(platform.categories),
      });
  }
}
