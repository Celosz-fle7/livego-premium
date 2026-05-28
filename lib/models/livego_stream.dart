class LiveGoStream {
  final String url;
  final String quality;
  final String resolution;
  final int duration;
  final List<LiveGoSubtitle> subtitles;
  final int nextVideoId;
  final int prevVideoId;
  final String title;

  const LiveGoStream({
    required this.url,
    required this.quality,
    required this.resolution,
    required this.duration,
    required this.subtitles,
    required this.nextVideoId,
    required this.prevVideoId,
    required this.title,
  });

  factory LiveGoStream.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'])
        : json;

    final streams = data['streams'];
    final first = streams is List && streams.isNotEmpty
        ? Map<String, dynamic>.from(streams.first)
        : <String, dynamic>{};

    final subs = data['subtitles'];

    return LiveGoStream(
      url: '${first['url'] ?? ''}',
      quality: '${first['quality'] ?? 'auto'}',
      resolution: '${first['resolution'] ?? 'auto'}',
      duration: int.tryParse('${first['duration'] ?? data['duration'] ?? 0}') ?? 0,
      subtitles: subs is List
          ? subs.map((e) {
              return LiveGoSubtitle.fromJson(
                Map<String, dynamic>.from(e),
              );
            }).toList()
          : const <LiveGoSubtitle>[],
      nextVideoId: int.tryParse('${data['next_video_id'] ?? 0}') ?? 0,
      prevVideoId: int.tryParse('${data['prev_video_id'] ?? 0}') ?? 0,
      title: '${data['title'] ?? ''}',
    );
  }
}

class LiveGoSubtitle {
  final String language;
  final String format;
  final String url;

  const LiveGoSubtitle({
    required this.language,
    required this.format,
    required this.url,
  });

  factory LiveGoSubtitle.fromJson(Map<String, dynamic> json) {
    return LiveGoSubtitle(
      language: '${json['language'] ?? ''}',
      format: '${json['format'] ?? ''}',
      url: '${json['url'] ?? ''}',
    );
  }
}
