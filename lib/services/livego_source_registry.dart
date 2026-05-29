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
    LiveGoSource(slug: 'shortmax', name: 'ShortMax', enabledByDefault: true),
    LiveGoSource(slug: 'netshort', name: 'NetShort', enabledByDefault: true),
    LiveGoSource(slug: 'pinedrama', name: 'PineDrama', enabledByDefault: true),
    LiveGoSource(slug: 'dramabox', name: 'DramaBox', enabledByDefault: true),
    LiveGoSource(slug: 'flickreels', name: 'FlickReels', enabledByDefault: true),
    LiveGoSource(slug: 'melolo', name: 'Melolo'),
  ];
  static List<LiveGoSource> get defaults {
    return all.where((e) => e.enabledByDefault).toList();
  }

  static List<String> get defaultSlugs {
    return defaults.map((e) => e.slug).toList();
  }
}
