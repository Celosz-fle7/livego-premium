class ContentItem {
  final String id;
  final String title;
  final String source;
  final String category;
  final String description;
  final String posterUrl;
  final String backdropUrl;
  final double rating;
  final int episodes;
  final bool updated;
  final String platformSlug;
  final String chapterId;
  final String lang;

  const ContentItem({
    required this.id,
    required this.title,
    required this.source,
    required this.category,
    required this.description,
    required this.posterUrl,
    required this.backdropUrl,
    required this.rating,
    required this.episodes,
    this.updated = false,
    this.platformSlug = 'shortmax',
    this.chapterId = '1',
    this.lang = 'id',
  });

  factory ContentItem.fromApi(
    Map<String, dynamic> json, {
    required String platformSlug,
    String lang = 'id',
  }) {
    final chaptersRaw = json['chapters'] ?? json['total_episodes'] ?? json['totalEpisodes'] ?? 1;
    final chapters = int.tryParse('$chaptersRaw') ?? (chaptersRaw is int ? chaptersRaw : 1);
    final genres = json['genres'];
    final tags = json['tags'];
    final firstGenre = genres is List && genres.isNotEmpty ? '${genres.first}' : '';
    final firstTag = tags is List && tags.isNotEmpty ? '${tags.first}' : '';

    return ContentItem(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Untitled'}',
      source: '${json['author'] ?? json['platform'] ?? platformSlug}',
      category: firstGenre.isNotEmpty ? firstGenre : (firstTag.isNotEmpty ? firstTag : 'Drama'),
      description: '${json['synopsis'] ?? json['description'] ?? ''}',
      posterUrl: _firstString(json, const [
        'cover',
        'poster',
        'cover_url',
        'poster_url',
        'coverUrl',
        'posterUrl',
        'imageUrl',
        'image_url',
        'thumbnail'
      ]),
      backdropUrl: _firstString(json, const [
        'backdrop',
        'backdrop_url',
        'backdropUrl',
        'banner',
        'banner_url',
        'bannerUrl',
        'cover',
        'poster',
        'cover_url',
        'poster_url',
        'coverUrl',
        'posterUrl',
        'imageUrl',
        'image_url'
      ]),
      rating: _parseRating(json),
      episodes: chapters <= 0 ? 1 : chapters,
      updated: '${json['status'] ?? ''}'.toLowerCase().contains('complete'),
      platformSlug: platformSlug,
      chapterId: '1',
      lang: lang,
    );
  }

  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final text = value == null ? '' : '$value'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  static double _parseRating(Map<String, dynamic> json) {
    final views = '${json['views'] ?? ''}';
    if (views.contains('M')) return 8.6;
    if (views.contains('K')) return 7.8;
    return 8.0;
  }
}
