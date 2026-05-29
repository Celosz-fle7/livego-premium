import 'dart:convert';
import 'dart:io';

import '../core/livego_settings.dart';
import '../models/content_item.dart';
import '../models/stream_info.dart';
import '../models/livego_episode.dart';

class AnichinApiClient {
  static const String baseUrl = 'https://priv-api.anichin.bio';
  static const String apiKey = 'dk_live_c261cb5920f82cf971e29edf0c8183d8';

  static const Map<String, String> _slugs = {
    'shortmax': 'shortmax',
    'netshort': 'netshort',
    'flickreels': 'flickreels',
    'melolo': 'melolo',
    'dramabox': 'dramabox',
    'pinedrama': 'pinedrama',
  };

  static const List<String> supportedPlatforms = [
    'shortmax',
    'netshort',
    'pinedrama',
    'dramabox',
    'flickreels',
    'melolo',
  ];

  static const List<String> defaultPlatforms = [
    'shortmax',
    'netshort',
    'pinedrama',
    'dramabox',
    'flickreels',
  ];

  static bool supports(String platform) => _slugs.containsKey(platform.toLowerCase());

  static String _apiSlug(String platform) => _slugs[platform.toLowerCase()] ?? platform.toLowerCase();

  static Future<List<ContentItem>> home({
    String platform = 'shortmax',
    String lang = 'id',
  }) async {
    final slug = _apiSlug(platform);
    final json = await _getJson('/api/$slug/trending', {
      'lang': lang,
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'shortmax',
    String lang = 'id',
    int page = 1,
  }) async {
    final slug = _apiSlug(platform);
    final json = await _getJson('/api/$slug/foryou', {
      'page': '$page',
      'lang': lang,
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> banner({
    String platform = 'shortmax',
    String lang = 'id',
  }) async {
    final rows = await home(platform: platform, lang: lang);
    return rows.take(8).toList();
  }

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'shortmax',
    String lang = 'id',
  }) async {
    if (query.trim().isEmpty) return [];
    final slug = _apiSlug(platform);
    final json = await _getJson('/api/$slug/search', {
      'query': query.trim(),
      'lang': lang,
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<ContentItem?> detail(ContentItem item) async {
    final slug = _apiSlug(item.platformSlug);
    final json = await _getJson('/api/$slug/detail', {
      'id': item.id,
      'lang': item.lang,
    });
    final data = _dataMap(json);
    if (data.isEmpty) return item;
    return _parseItem(data, platform: item.platformSlug, lang: item.lang);
  }


  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async {
    final slug = _apiSlug(item.platformSlug);
    Map<String, dynamic> json = <String, dynamic>{};
    try {
      json = await _getJson('/api/$slug/allepisode', {
        'id': item.id,
        'lang': item.lang,
      });
    } catch (_) {
      json = await _getJson('/api/$slug/detail', {
        'id': item.id,
        'lang': item.lang,
      });
    }

    final raw = _episodeList(json);
    if (raw.isNotEmpty) {
      return raw.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final row = entry.value;
        final id = _first(row, const ['id', 'chapterId', 'chapter_id', 'episodeId', 'episode_id', 'ep'], fallback: '$idx');
        final title = _first(row, const ['title', 'name', 'episodeTitle', 'episode_title'], fallback: 'Episode $idx');
        return LiveGoEpisode(id: id, index: idx, title: title);
      }).toList();
    }

    final total = item.episodes <= 0 ? 1 : item.episodes;
    return List.generate(total, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'));
  }

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) async {
    final slug = _apiSlug(item.platformSlug);
    final chapter = '${chapterId ?? item.chapterId}';
    final ep = int.tryParse(chapter) ?? 1;
    final json = await _getJson('/api/$slug/episode', {
      'id': item.id,
      'ep': '$ep',
      if (int.tryParse(chapter) == null) 'chapterId': chapter,
      'lang': item.lang,
      if (_qualityParam.isNotEmpty) 'q': _qualityParam,
    });
    return _parseStream(json, item: item, ep: ep);
  }

  static String get _qualityParam {
    final q = LiveGoSettings.quality.toLowerCase();
    if (q.contains('1080')) return '1080p';
    if (q.contains('720')) return '720p';
    if (q.contains('480')) return '480p';
    return '';
  }

  static Future<Map<String, dynamic>> _getJson(String path, Map<String, String> query) async {
    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 18));
      request.headers.set('X-API-Key', apiKey);
      request.headers.set('Accept', 'application/json');
      request.headers.set('User-Agent', 'okhttp/4.12.0');

      final response = await request.close().timeout(const Duration(seconds: 18));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('ANICHIN API ${response.statusCode} ${uri.path}: $body');
      }

      if (body.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'success': true, 'data': decoded};
    } finally {
      client.close(force: true);
    }
  }

  static List<ContentItem> _parseItems(
    Map<String, dynamic> json, {
    required String platform,
    required String lang,
  }) {
    final raw = _dataList(json);
    return raw
        .map((e) => _parseItem(e, platform: platform, lang: lang))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _dataList(Map<String, dynamic> json) {
    Object? data = json['data'];
    if (data is Map) {
      data = data['items'] ??
          data['list'] ??
          data['results'] ??
          data['dramas'] ??
          data['books'] ??
          data['rows'] ??
          data['data'];
    }
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }


  static List<Map<String, dynamic>> _episodeList(Map<String, dynamic> json) {
    Object? data = json['data'];
    if (data is Map) {
      data = data['episodes'] ??
          data['episodeList'] ??
          data['episode_list'] ??
          data['chapters'] ??
          data['list'] ??
          data['items'] ??
          data['rows'] ??
          data['data'];
    }
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _dataMap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static ContentItem _parseItem(
    Map<String, dynamic> json, {
    required String platform,
    required String lang,
  }) {
    final id = _first(json, const [
      'id',
      'bookId',
      'book_id',
      'dramaId',
      'drama_id',
      'seriesId',
      'series_id',
    ]);

    final title = _first(json, const [
      'title',
      'name',
      'bookName',
      'book_name',
      'dramaName',
      'drama_name',
    ], fallback: 'Untitled');

    final cover = _first(json, const [
      'cover',
      'poster',
      'posterUrl',
      'poster_url',
      'image',
      'imageUrl',
      'thumb',
      'thumbnail',
      'thumbnailUrl',
    ]);

    final backdrop = _first(json, const [
      'backdrop',
      'backdropUrl',
      'banner',
      'bannerUrl',
      'cover',
      'poster',
      'image',
    ]);

    final description = _first(json, const [
      'synopsis',
      'description',
      'desc',
      'intro',
      'summary',
    ]);

    final source = _first(json, const ['platform', 'source', 'author'], fallback: platform);

    final category = _category(json);
    final episodes = _episodes(json);

    return ContentItem(
      id: id,
      title: title,
      source: source.isEmpty ? platform : source,
      category: category,
      description: description,
      posterUrl: cover,
      backdropUrl: backdrop.isEmpty ? cover : backdrop,
      rating: 8.0,
      episodes: episodes <= 0 ? 1 : episodes,
      updated: true,
      platformSlug: platform,
      chapterId: '1',
      lang: lang,
    );
  }

  static StreamInfo _parseStream(
    Map<String, dynamic> json, {
    required ContentItem item,
    required int ep,
  }) {
    final data = _dataMap(json);
    final streamData = _streamData(data);
    final url = _extractUrl(streamData);

    final subtitles = <SubtitleTrack>[];
    final subtitlesRaw = streamData['subtitles'] ??
        streamData['subtitle'] ??
        streamData['subtitleTracks'] ??
        streamData['tracks'];
    if (subtitlesRaw is List) {
      for (final row in subtitlesRaw) {
        if (row is Map) {
          final subUrl = _first(Map<String, dynamic>.from(row), const [
            'url',
            'vttUrl',
            'vtt_url',
            'subtitleUrl',
            'subtitle_url',
            'src',
          ]);
          if (subUrl.isNotEmpty) {
            subtitles.add(SubtitleTrack(
              language: _first(Map<String, dynamic>.from(row), const [
                'language',
                'lang',
                'label',
                'name',
              ], fallback: item.lang),
              format: subUrl.toLowerCase().contains('.srt') ? 'srt' : 'vtt',
              url: subUrl,
            ));
          }
        }
      }
    }

    final total = _parseInt(
      streamData['totalEpisodes'] ??
          streamData['total_episodes'] ??
          streamData['episodes'] ??
          item.episodes,
      fallback: item.episodes,
    );

    return StreamInfo(
      url: url,
      episodeIndex: _parseInt(
        streamData['episode_index'] ?? streamData['episodeIndex'] ?? streamData['ep'] ?? ep,
        fallback: ep,
      ),
      totalEpisodes: total <= 0 ? item.episodes : total,
      nextEpisodeId: ep < (total <= 0 ? item.episodes : total) ? '${ep + 1}' : '0',
      prevEpisodeId: ep > 1 ? '${ep - 1}' : '0',
      headers: const <String, String>{
        'User-Agent': 'okhttp/4.12.0',
        'Accept': '*/*',
      },
      subtitles: subtitles,
    );
  }

  static Map<String, dynamic> _streamData(Map<String, dynamic> data) {
    final candidates = [
      data,
      if (data['episode'] is Map) Map<String, dynamic>.from(data['episode'] as Map),
      if (data['video'] is Map) Map<String, dynamic>.from(data['video'] as Map),
      if (data['stream'] is Map) Map<String, dynamic>.from(data['stream'] as Map),
    ];

    for (final c in candidates) {
      if (_extractUrl(c).isNotEmpty) return c;
    }
    return data;
  }

  static String _extractUrl(Map<String, dynamic> data) {
    final direct = _first(data, const [
      'url',
      'videoUrl',
      'video_url',
      'playUrl',
      'play_url',
      'mp4Url',
      'mp4_url',
      'hlsUrl',
      'hls_url',
      'm3u8',
      'src',
    ]);
    if (direct.isNotEmpty) return direct;

    final streams = data['streams'] ?? data['qualities'] ?? data['urls'] ?? data['videos'];
    if (streams is List && streams.isNotEmpty) {
      final preferred = _qualityParam;
      Map? fallback;
      for (final row in streams) {
        if (row is! Map) continue;
        fallback ??= row;
        final quality = '${row['quality'] ?? row['resolution'] ?? row['label'] ?? ''}'.toLowerCase();
        if (preferred.isNotEmpty && quality.contains(preferred.replaceAll('p', ''))) {
          return _first(Map<String, dynamic>.from(row), const ['url', 'src', 'videoUrl', 'hlsUrl', 'mp4Url']);
        }
      }
      if (fallback != null) {
        return _first(Map<String, dynamic>.from(fallback), const ['url', 'src', 'videoUrl', 'hlsUrl', 'mp4Url']);
      }
    }

    if (streams is Map) {
      final preferred = _qualityParam;
      if (preferred.isNotEmpty && streams[preferred] != null) return '${streams[preferred]}';
      for (final key in ['auto', '1080p', '720p', '480p', 'url']) {
        if (streams[key] != null) return '${streams[key]}';
      }
    }

    return '';
  }

  static String _category(Map<String, dynamic> json) {
    final genres = json['genres'] ?? json['genre'] ?? json['categories'] ?? json['tags'];
    if (genres is List && genres.isNotEmpty) {
      final first = '${genres.first}'.trim();
      if (first.isNotEmpty) return first;
    }
    if (genres is String && genres.trim().isNotEmpty) return genres.trim();
    return 'Drama';
  }

  static int _episodes(Map<String, dynamic> json) {
    final raw = json['chapters'] ??
        json['total_episodes'] ??
        json['totalEpisodes'] ??
        json['episodeCount'] ??
        json['episode_count'] ??
        json['episodes'];
    if (raw is List) return raw.length;
    return _parseInt(raw, fallback: 1);
  }

  static String _first(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = '$value'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  static int _parseInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }
}
