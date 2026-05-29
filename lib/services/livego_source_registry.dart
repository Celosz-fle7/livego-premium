class LiveGoSource {
  final String slug;
  final String name;
  final bool enabledByDefault;

  const LiveGoSource({
    required this.slug,
    required this.name,
    this.enabledByDefault = false,
  });
}

class LiveGoSourceRegistry {
  static const List<LiveGoSource> all = [
    LiveGoSource(slug: 'freereels', name: 'FreeReels', enabledByDefault: true),
    LiveGoSource(slug: 'goodshort', name: 'GoodShort', enabledByDefault: true),
    LiveGoSource(slug: 'dramawave', name: 'DramaWave', enabledByDefault: true),
    LiveGoSource(slug: 'netshort', name: 'NetShort', enabledByDefault: true),
    LiveGoSource(slug: 'reelshort', name: 'ReelShort', enabledByDefault: true),
    LiveGoSource(slug: 'shortmax', name: 'ShortMax'),

    LiveGoSource(slug: 'reelife', name: 'Reelife'),
    LiveGoSource(slug: 'rapidtv', name: 'RapidTV'),
    LiveGoSource(slug: 'flickreels', name: 'FlickReels'),
    LiveGoSource(slug: 'dramapoops', name: 'DramaPoops'),
    LiveGoSource(slug: 'dramanova', name: 'DramaNova'),
    LiveGoSource(slug: 'dramarush', name: 'DramaRush'),
    LiveGoSource(slug: 'melolo', name: 'Melolo', enabledByDefault: true),
    LiveGoSource(slug: 'starshort', name: 'StarShort'),
    LiveGoSource(slug: 'meloshort', name: 'MeloShort'),
    LiveGoSource(slug: 'dramabite', name: 'DramaBite'),
    LiveGoSource(slug: 'stardusttv', name: 'StardustTV'),
    LiveGoSource(slug: 'dramabox', name: 'DramaBox'),
    LiveGoSource(slug: 'drachin', name: 'Drachin'),
    LiveGoSource(slug: 'dramapops', name: 'DramaPops'),
  ];

  static List<LiveGoSource> get defaults {
    return all.where((e) => e.enabledByDefault).toList();
  }

  static List<String> get defaultSlugs {
    return defaults.map((e) => e.slug).toList();
  }
}
