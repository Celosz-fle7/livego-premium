class LiveGoSettings {
  static const appName = 'LiveGo';

  static String language = 'id';
  static String defaultPlatform = 'freereels';
  static String quality = 'Auto';
  static String layoutMode = 'Auto';
  static bool subtitlesEnabled = true;
  static bool autoNextEnabled = true;
  static bool downloadWifiOnly = true;
  static bool lowEndTvMode = true;

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

  static bool isPlatformActive(String slug) => activePlatforms.contains(slug);

  static void togglePlatform(String slug) {
    if (activePlatforms.contains(slug)) {
      if (activePlatforms.length > 1) activePlatforms.remove(slug);
    } else {
      activePlatforms.add(slug);
    }
    if (!activePlatforms.contains(defaultPlatform)) {
      defaultPlatform = activePlatforms.first;
    }
  }

  static void reset() {
    language = 'id';
    defaultPlatform = 'freereels';
    quality = 'Auto';
    layoutMode = 'Auto';
    subtitlesEnabled = true;
    autoNextEnabled = true;
    downloadWifiOnly = true;
    lowEndTvMode = true;
    activePlatforms
      ..clear()
      ..addAll(defaultPlatforms);
  }
}
