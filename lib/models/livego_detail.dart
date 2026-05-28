import 'livego_episode.dart';

class LiveGoDetail {
  final String id;
  final String title;
  final String cover;
  final String synopsis;
  final String author;
  final String status;
  final List<String> genres;
  final int totalEpisodes;
  final List<LiveGoEpisode> episodes;
  final String platform;

  const LiveGoDetail({
    required this.id,
    required this.title,
    required this.cover,
    required this.synopsis,
    required this.author,
    required this.status,
    required this.genres,
    required this.totalEpisodes,
    required this.episodes,
    required this.platform,
  });

  factory LiveGoDetail.fromJson(
    Map<String, dynamic> json, {
    String platform = '',
  }) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'])
        : json;

    final chapters = data['chapters'];

    return LiveGoDetail(
      id: '${data['id'] ?? ''}',
      title: '${data['title'] ?? ''}',
      cover: '${data['cover'] ?? ''}',
      synopsis: '${data['synopsis'] ?? ''}',
      author: '${data['author'] ?? ''}',
      status: '${data['status'] ?? ''}',
      genres: (data['genres'] is List)
          ? List<String>.from(data['genres'].map((e) => '$e'))
          : const <String>[],
      totalEpisodes: int.tryParse('${data['total_episodes'] ?? data['chapters'] ?? 0}') ?? 0,
      episodes: chapters is List
          ? chapters.map((e) {
              return LiveGoEpisode.fromJson(
                Map<String, dynamic>.from(e),
              );
            }).toList()
          : const <LiveGoEpisode>[],
      platform: platform,
    );
  }
}
