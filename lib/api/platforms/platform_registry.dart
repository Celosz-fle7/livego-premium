class PlatformRegistry {
  PlatformRegistry._();

  /// Default Home platforms: only platforms verified stable with HMAC.
  static const List<String> defaultHomePlatforms = [
    'freereels',
    'goodshort',
    'dramawave',
    'netshort',
    'reelshort',
    'melolo',
  ];

  static const List<String> verifiedPlatforms = [
    'freereels',
    'goodshort',
    'dramawave',
    'netshort',
    'reelshort',
    'melolo',
    'rapidtv',
  ];

  /// Full list exposed to Source Manager. Some can be offline/403 depending on API provider.
  static const List<String> supportedPlatforms = [
    'freereels',
    'goodshort',
    'dramawave',
    'netshort',
    'reelshort',
    'melolo',
    'rapidtv',
    'reelife',
    'flickreels',
    'dramapops',
    'dramapoops',
    'shortmax',
    'dramanova',
    'dramarush',
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

  static String label(String slug) {
    return slug
        .split(RegExp(r'[_-]'))
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }
}
