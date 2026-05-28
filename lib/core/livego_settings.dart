class LiveGoSettings {
  static const appName = 'LiveGo';
  static const patchVersion = 'home-api-source-manager-recovery-v2';

  static String language = 'id';
  static String defaultPlatform = 'freereels';
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

  static final List<String> defaultPlatforms = [
    'freereels',
    'goodshort',
    'dramawave',
    'netshort',
    'reelshort',
    'melolo',
  ];

  static final List<String> supportedPlatforms = [
    'freereels',
    'goodshort',
    'dramawave',
    'netshort',
    'reelshort',
    'reelife',
    'rapidtv',
    'flickreels',
    'dramapops',
    'dramapoops',
    'shortmax',
    'dramanova',
    'dramarush',
    'melolo',
    'starshort',
    'meloshort',
    'dramabite',
    'stardusttv',
    'dramabox',
    'drachin',
    'youku',
    'tencent',
    'iqiyi',
    'mango',
    'wetv',
    'viki',
    'shorttv',
    'minidrama',
    'topreels',
    'moboreels',
    'flexreels',
    'livego',
  ];

  static final Set<String> activePlatforms = defaultPlatforms.toSet();
  static final List<String> homePlatforms = List<String>.from(defaultPlatforms);

  static final Map<String, List<String>> homeCategories = {
    for (final platform in defaultPlatforms) platform: ['Trending', 'New', 'Drama', 'Movies', 'Anime', 'Dubbing'],
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

  static List<String> categoriesFor(String platform) {
    return List<String>.from(homeCategories[platform] ?? const ['Trending', 'New', 'Drama', 'Movies', 'Anime', 'Dubbing']);
  }

  static void setCategoriesFor(String platform, List<String> values) {
    final clean = values.where((e) => e.trim().isNotEmpty).take(6).toList();
    homeCategories[platform] = clean.isEmpty ? ['Trending'] : clean;
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
    defaultPlatform = 'freereels';
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
    activePlatforms
      ..clear()
      ..addAll(defaultPlatforms);
    homePlatforms
      ..clear()
      ..addAll(defaultPlatforms);
    homeCategories
      ..clear()
      ..addEntries(defaultPlatforms.map((p) => MapEntry(p, ['Trending', 'New', 'Drama', 'Movies', 'Anime', 'Dubbing'])));
  }
}
