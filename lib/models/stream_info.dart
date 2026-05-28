class StreamInfo {
  final String url;
  final int episodeIndex;
  final int totalEpisodes;
  final String nextEpisodeId;
  final String prevEpisodeId;
  final Map<String, String> headers;
  final List<SubtitleTrack> subtitles;

  const StreamInfo({
    required this.url,
    required this.episodeIndex,
    required this.totalEpisodes,
    required this.nextEpisodeId,
    required this.prevEpisodeId,
    required this.headers,
    required this.subtitles,
  });

  static const empty = StreamInfo(
    url: '',
    episodeIndex: 1,
    totalEpisodes: 1,
    nextEpisodeId: '0',
    prevEpisodeId: '0',
    headers: <String, String>{},
    subtitles: <SubtitleTrack>[],
  );

  factory StreamInfo.fromApi(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : <String, dynamic>{};
    final streams = data['streams'];
    String url = '';
    if (streams is List && streams.isNotEmpty) {
      final first = streams.first;
      if (first is Map && first['url'] != null) url = '${first['url']}';
    }

    final headersRaw = data['streamHeaders'];
    final headers = <String, String>{};
    if (headersRaw is Map) {
      for (final entry in headersRaw.entries) {
        if (entry.key != null && entry.value != null) {
          headers['${entry.key}'] = '${entry.value}';
        }
      }
    }
    headers.putIfAbsent('User-Agent', () => 'okhttp/4.12.0');
    headers.putIfAbsent('Accept', () => '*/*');

    final subtitlesRaw = data['subtitles'];
    final subtitles = <SubtitleTrack>[];
    if (subtitlesRaw is List) {
      for (final row in subtitlesRaw) {
        if (row is Map) {
          final url = '${row['url'] ?? ''}';
          if (url.isNotEmpty) {
            subtitles.add(SubtitleTrack(
              language: '${row['language'] ?? row['lang'] ?? 'id'}',
              format: '${row['format'] ?? 'srt'}',
              url: url,
            ));
          }
        }
      }
    }

    final totalRaw = data['total_episodes'] ?? data['totalEpisodes'] ?? data['chapters'] ?? 1;
    final epRaw = data['episode_index'] ?? data['episodeIndex'] ?? 1;

    return StreamInfo(
      url: url,
      episodeIndex: _parseInt(epRaw, fallback: 1),
      totalEpisodes: _parseInt(totalRaw, fallback: 1),
      nextEpisodeId: '${data['next_video_id'] ?? data['nextVideoId'] ?? '0'}',
      prevEpisodeId: '${data['prev_video_id'] ?? data['prevVideoId'] ?? '0'}',
      headers: headers,
      subtitles: subtitles,
    );
  }

  static int _parseInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }
}

class SubtitleTrack {
  final String language;
  final String format;
  final String url;

  const SubtitleTrack({
    required this.language,
    required this.format,
    required this.url,
  });
}
