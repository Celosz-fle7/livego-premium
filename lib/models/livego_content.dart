class LiveGoContent {
  final String id;
  final String title;
  final String author;
  final String cover;
  final String synopsis;
  final String status;
  final String views;
  final String chapters;
  final List<String> genres;
  final List<String> tags;
  final String platform;

  const LiveGoContent({
    required this.id,
    required this.title,
    required this.author,
    required this.cover,
    required this.synopsis,
    required this.status,
    required this.views,
    required this.chapters,
    required this.genres,
    required this.tags,
    required this.platform,
  });

  factory LiveGoContent.fromJson(
    Map<String, dynamic> json, {
    String platform = '',
  }) {
    return LiveGoContent(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      author: '${json['author'] ?? ''}',
      cover: '${json['cover'] ?? json['poster'] ?? ''}',
      synopsis: '${json['synopsis'] ?? json['description'] ?? ''}',
      status: '${json['status'] ?? ''}',
      views: '${json['views'] ?? ''}',
      chapters: '${json['chapters'] ?? json['total_episodes'] ?? ''}',
      genres: (json['genres'] is List)
          ? List<String>.from(json['genres'].map((e) => '$e'))
          : const <String>[],
      tags: (json['tags'] is List)
          ? List<String>.from(json['tags'].map((e) => '$e'))
          : const <String>[],
      platform: platform,
    );
  }
}
