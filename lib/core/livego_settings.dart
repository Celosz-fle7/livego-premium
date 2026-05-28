class LiveGoSettings {
  static const appName = 'LiveGo';

  static String language = 'id';
  static String defaultPlatform = 'freereels';
  static String quality = 'Auto';
  static String layoutMode = 'Auto';

  static final List<String> defaultPlatforms = [
    'freereels',
    'goodshort',
    'shortmax',
    'dramabox',
    'reelshort',
    'netshort',
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
    'kalos',
    'flextv',
    'moboreels',
    'myfantasy',
    'goodfm',
    'lokshorts',
    'joyreels',
    'topreels',
    'minishorts',
    'hotshorts',
    'reelplay',
    'novelshort',
  ];

  static void reset() {
    language = 'id';
    defaultPlatform = 'freereels';
    quality = 'Auto';
    layoutMode = 'Auto';
  }
}
