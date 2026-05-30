class StreamInfo {
  final String url;
  final int episodeIndex;
  final int totalEpisodes;
  final String nextEpisodeId;
  final String prevEpisodeId;
  final Map<String, String> headers;
  final List<SubtitleTrack> subtitles;
  final List<StreamQuality> qualities;

  const StreamInfo({
    required this.url,
    required this.episodeIndex,
    required this.totalEpisodes,
    required this.nextEpisodeId,
    required this.prevEpisodeId,
    required this.headers,
    required this.subtitles,
    this.qualities = const <StreamQuality>[],
  });

  static const empty = StreamInfo(
    url: '',
    episodeIndex: 1,
    totalEpisodes: 1,
    nextEpisodeId: '0',
    prevEpisodeId: '0',
    headers: <String, String>{},
    subtitles: <SubtitleTrack>[],
    qualities: <StreamQuality>[],
  );

  factory StreamInfo.fromApi(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : <String, dynamic>{};
    final streams = data['streams'];
    String url = '';
    final qualities = <StreamQuality>[];
    if (streams is List && streams.isNotEmpty) {
      for (final row in streams) {
        if (row is Map) {
          final map = Map<String, dynamic>.from(row);
          final qUrl = '${map['url'] ?? map['src'] ?? map['videoUrl'] ?? ''}'.trim();
          if (qUrl.isEmpty) continue;
          final label = '${map['label'] ?? map['quality'] ?? map['resolution'] ?? 'Auto'}'.trim();
          qualities.add(StreamQuality(label: label.isEmpty ? 'Auto' : label, url: qUrl, isDefault: map['isDefault'] == true));
        }
      }
      if (qualities.isNotEmpty) url = qualities.first.url;
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
      qualities: qualities,
    );
  }

  String urlForQuality(String quality) {
    if (qualities.isEmpty) return url;
    final q = quality.toLowerCase();
    if (q == 'auto') return autoStartUrl;
    final direct = qualities.where((e) => e.label.toLowerCase().contains(q.replaceAll('p', ''))).toList();
    if (direct.isNotEmpty) return direct.first.url;
    return url;
  }

  String get autoStartUrl {
    if (qualities.isEmpty) return url;
    final sorted = List<StreamQuality>.from(qualities)..sort((a, b) => a.height.compareTo(b.height));
    final low = sorted.where((e) => e.height > 0).toList();
    if (low.isNotEmpty) return low.first.url;
    return qualities.first.url;
  }

  String get autoBestUrl {
    if (qualities.isEmpty) return url;
    final sorted = List<StreamQuality>.from(qualities)..sort((a, b) => b.height.compareTo(a.height));
    final high = sorted.where((e) => e.height > 0).toList();
    if (high.isNotEmpty) return high.first.url;
    final def = qualities.where((e) => e.isDefault).toList();
    return def.isNotEmpty ? def.first.url : qualities.first.url;
  }

  static int _parseInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }
}

class StreamQuality {
  final String label;
  final String url;
  final bool isDefault;

  const StreamQuality({
    required this.label,
    required this.url,
    this.isDefault = false,
  });

  int get height {
    final match = RegExp(r'(\d{3,4})').firstMatch(label);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
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
