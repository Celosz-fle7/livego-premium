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
    final apiLang = _providerLang(slug, lang);
    final json = await _getJson('/api/$slug/trending', {
      'lang': apiLang,
    });
    return _parseItems(json, platform: platform, lang: apiLang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'shortmax',
    String lang = 'id',
    int page = 1,
  }) async {
    final slug = _apiSlug(platform);
    final apiLang = _providerLang(slug, lang);
    final json = await _getJson('/api/$slug/foryou', {
      'page': '$page',
      'lang': apiLang,
    });
    return _parseItems(json, platform: platform, lang: apiLang);
  }

  static Future<List<ContentItem>> collection({
    String platform = 'shortmax',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) async {
    final slug = _apiSlug(platform);
    final apiLang = _providerLang(slug, lang);
    final key = collection.toLowerCase().replaceAll(' ', '');
    final json = await _getJson('/api/$slug/$key', {
      if (key == 'foryou') 'page': '$page',
      'lang': apiLang,
    });
    return _parseItems(json, platform: platform, lang: apiLang);
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
    final apiLang = _providerLang(slug, lang);
    final json = await _getJson('/api/$slug/search', {
      _searchParam(slug): query.trim(),
      'lang': apiLang,
    });
    return _parseItems(json, platform: platform, lang: apiLang);
  }

  static Future<ContentItem?> detail(ContentItem item) async {
    final slug = _apiSlug(item.platformSlug);
    final apiLang = _providerLang(slug, item.lang);
    final json = await _getJson('/api/$slug/detail', {
      'id': item.id,
      'lang': apiLang,
    });
    final data = _dataMap(json);
    if (data.isEmpty) return item;

    // Some Anichin providers, especially ShortMax, can return detail payloads
    // with an empty `id` even though the request id is valid. If we pass that
    // empty id into the player, /episode receives id= and the UI shows
    // "Stream belum tersedia dari API" even while the real endpoint works.
    final parsed = _parseItem(data, platform: item.platformSlug, lang: apiLang);
    return _preserveIdentity(parsed, fallback: item, lang: apiLang);
  }

  static ContentItem _preserveIdentity(
    ContentItem parsed, {
    required ContentItem fallback,
    required String lang,
  }) {
    return ContentItem(
      id: parsed.id.isNotEmpty ? parsed.id : fallback.id,
      title: parsed.title.trim().isNotEmpty && parsed.title != 'Untitled' ? parsed.title : fallback.title,
      source: parsed.source.trim().isNotEmpty ? parsed.source : fallback.source,
      category: parsed.category.trim().isNotEmpty ? parsed.category : fallback.category,
      description: parsed.description.trim().isNotEmpty ? parsed.description : fallback.description,
      posterUrl: parsed.posterUrl.trim().isNotEmpty ? parsed.posterUrl : fallback.posterUrl,
      backdropUrl: parsed.backdropUrl.trim().isNotEmpty ? parsed.backdropUrl : fallback.backdropUrl,
      rating: parsed.rating,
      episodes: parsed.episodes > 0 ? parsed.episodes : fallback.episodes,
      updated: parsed.updated || fallback.updated,
      platformSlug: parsed.platformSlug.trim().isNotEmpty ? parsed.platformSlug : fallback.platformSlug,
      chapterId: parsed.chapterId.trim().isNotEmpty ? parsed.chapterId : fallback.chapterId,
      lang: lang,
    );
  }


  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async {
    final slug = _apiSlug(item.platformSlug);
    Map<String, dynamic> json = <String, dynamic>{};
    final apiLang = _providerLang(slug, item.lang);
    try {
      json = await _getJson('/api/$slug/allepisode', {
        'id': item.id,
        'lang': apiLang,
      });
    } catch (_) {
      json = await _getJson('/api/$slug/detail', {
        'id': item.id,
        'lang': apiLang,
      });
    }

    final raw = _episodeList(json);
    if (raw.isNotEmpty) {
      return raw.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final row = entry.value;
        final number = _parseInt(
          row['number'] ?? row['episode'] ?? row['episodeNumber'] ?? row['episode_number'] ?? row['ep'] ?? row['index'],
          fallback: idx,
        );
        final id = '$number';
        final title = _first(row, const ['chapterName', 'chapter_name', 'title', 'name', 'episodeTitle', 'episode_title'], fallback: 'Episode $number');
        return LiveGoEpisode(id: id, index: number, title: title);
      }).toList();
    }

    final total = item.episodes <= 0 ? 1 : item.episodes;
    return List.generate(total, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'));
  }

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) async {
    final slug = _apiSlug(item.platformSlug);
    final apiLang = _providerLang(slug, item.lang);
    final chapter = '${chapterId ?? item.chapterId}';
    final ep = _episodeNumber(chapter);
    final playableId = item.id.trim();
    if (playableId.isEmpty) {
      print('ANICHIN STREAM EMPTY ID ${item.platformSlug} ep=$ep title=${item.title}');
      return StreamInfo.empty;
    }

    final query = <String, String>{
      'id': playableId,
      'ep': '$ep',
      'lang': apiLang,
      if (_qualityParam.isNotEmpty) 'q': _qualityParam,
    };

    // Provider-aware route based on the Anichin endpoint contract and Termux
    // checks:
    // - ShortMax/PineDrama/FlickReels expose playable streams from /episode.
    // - DramaBox exposes playable signed hlsUrl in /allepisode.
    // - NetShort can return an empty body when upstream is unavailable, so keep
    //   the player safe and return StreamInfo.empty instead of crashing.
    if (slug == 'dramabox') {
      final stream = await _streamFromAllEpisodes(item, ep: ep, slug: slug, lang: apiLang);
      if (stream.url.isNotEmpty) return stream;
      return StreamInfo.empty;
    }

    final stream = await _streamFromEpisodeEndpoint(item, query: query, ep: ep, slug: slug, lang: apiLang);
    if (stream.url.isNotEmpty) return stream;

    // Some providers may include stream fields in /allepisode as a fallback.
    final fallback = await _streamFromAllEpisodes(item, ep: ep, slug: slug, lang: apiLang);
    if (fallback.url.isNotEmpty) return fallback;

    return StreamInfo.empty;
  }

  static Future<StreamInfo> _streamFromEpisodeEndpoint(
    ContentItem item, {
    required Map<String, String> query,
    required int ep,
    required String slug,
    required String lang,
  }) async {
    try {
      final json = await _getJson('/api/$slug/episode', query);
      if (json.isEmpty) return StreamInfo.empty;
      return _parseStream(json, item: item, ep: ep, slug: slug, lang: lang);
    } catch (e) {
      print('ANICHIN EPISODE STREAM EMPTY $slug ep=$ep: $e');
      return StreamInfo.empty;
    }
  }

  static Future<StreamInfo> _streamFromAllEpisodes(
    ContentItem item, {
    required int ep,
    required String slug,
    required String lang,
  }) async {
    try {
      final all = await _getJson('/api/$slug/allepisode', {
        'id': item.id,
        'lang': lang,
      });
      final row = _findEpisodeRow(all, ep);
      if (row == null) return StreamInfo.empty;
      return _parseStream(row, item: item, ep: ep, slug: slug, lang: lang);
    } catch (e) {
      print('ANICHIN ALLEPISODE STREAM EMPTY $slug ep=$ep: $e');
      return StreamInfo.empty;
    }
  }

  static int _episodeNumber(String chapter) {
    final direct = int.tryParse(chapter);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'\d+').firstMatch(chapter);
    final parsed = match == null ? null : int.tryParse(match.group(0)!);
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }


  static String _providerLang(String slug, String requested) {
    // Use provider-documented defaults. Invalid lang values can make a valid
    // video endpoint return an empty payload, which appears as "stream unavailable".
    switch (slug) {
      case 'shortmax':
      case 'melolo':
        return 'id';
      case 'netshort':
        return 'in';
      case 'dramabox':
      case 'pinedrama':
      case 'flickreels':
        return 'en';
    }
    return requested.trim().isEmpty ? 'id' : requested.trim();
  }

  static String _searchParam(String slug) {
    switch (slug) {
      case 'melolo':
      case 'pinedrama':
      case 'dramabox':
        return 'q';
      default:
        return 'query';
    }
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
    final direct = _asList(json['data']) ??
        _asList(json['items']) ??
        _asList(json['list']) ??
        _asList(json['results']) ??
        _asList(json['dramas']) ??
        _asList(json['books']) ??
        _asList(json['rows']);
    if (direct != null) return direct;

    final found = _findFirstList(json);
    return found ?? <Map<String, dynamic>>[];
  }

  static List<Map<String, dynamic>>? _asList(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _asList(map['items']) ??
          _asList(map['list']) ??
          _asList(map['results']) ??
          _asList(map['dramas']) ??
          _asList(map['books']) ??
          _asList(map['rows']) ??
          _asList(map['data']);
    }
    return null;
  }

  static List<Map<String, dynamic>>? _findFirstList(Object? value) {
    if (value is List) {
      final rows = value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return rows.isEmpty ? null : rows;
    }
    if (value is Map) {
      for (final entry in value.values) {
        final rows = _findFirstList(entry);
        if (rows != null && rows.isNotEmpty) return rows;
      }
    }
    return null;
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
      'bookID',
      'dramaID',
      'showId',
      'show_id',
    ]);

    final title = _first(json, const [
      'title',
      'name',
      'bookName',
      'book_name',
      'dramaName',
      'drama_name',
      'bookTitle',
      'book_title',
      'seriesName',
      'series_name',
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
      'coverUrl',
      'cover_url',
      'pic',
      'picUrl',
      'pic_url',
      'verticalCover',
      'horizontalCover',
    ]);

    final backdrop = _first(json, const [
      'backdrop',
      'backdropUrl',
      'banner',
      'bannerUrl',
      'cover',
      'poster',
      'image',
      'horizontalCover',
      'verticalCover',
      'coverUrl',
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

  static Future<StreamInfo> _parseStream(
    Map<String, dynamic> json, {
    required ContentItem item,
    required int ep,
    required String slug,
    required String lang,
  }) async {
    final data = _dataMap(json);
    final streamData = _streamData(data);
    final url = _normalizePlayableUrl(_extractUrl(streamData));

    final subtitles = <SubtitleTrack>[];
    final subtitlesRaw = streamData['subtitles'] ??
        streamData['subtitle'] ??
        streamData['subtitleTracks'] ??
        streamData['tracks'] ??
        streamData['captions'];
    _appendSubtitles(subtitles, subtitlesRaw, fallbackLang: lang);

    final subtitlesUrl = _first(streamData, const [
      'subtitlesUrl',
      'subtitles_url',
      'subtitleEndpoint',
      'subtitle_endpoint',
    ]);
    if (subtitlesUrl.isNotEmpty) {
      subtitles.add(SubtitleTrack(
        language: lang,
        format: subtitlesUrl.toLowerCase().contains('.srt') ? 'srt' : 'vtt',
        url: _normalizePlayableUrl(subtitlesUrl),
      ));
    }

    if (slug == 'dramabox' && subtitles.isEmpty) {
      try {
        final subJson = await _getJson('/api/dramabox/subtitles', {
          'id': item.id,
          'ep': '$ep',
          'lang': lang,
        });
        _appendSubtitles(subtitles, _dataList(subJson), fallbackLang: lang);
      } catch (e) {
        print('DRAMABOX SUBTITLE ERROR ep=$ep: $e');
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
      qualities: _extractQualities(streamData),
    );
  }

  static Map<String, dynamic> _streamData(Map<String, dynamic> data) {
    final candidates = [
      data,
      if (data['data'] is Map) Map<String, dynamic>.from(data['data'] as Map),
      if (data['episode'] is Map) Map<String, dynamic>.from(data['episode'] as Map),
      if (data['video'] is Map) Map<String, dynamic>.from(data['video'] as Map),
      if (data['stream'] is Map) Map<String, dynamic>.from(data['stream'] as Map),
      if (data['play'] is Map) Map<String, dynamic>.from(data['play'] as Map),
    ];

    for (final c in candidates) {
      if (_extractUrl(c).isNotEmpty) return c;
    }
    return data;
  }

  static String _extractUrl(Map<String, dynamic> data) {
    final streams = data['qualityList'] ??
        data['quality_list'] ??
        data['streams'] ??
        data['qualities'] ??
        data['urls'] ??
        data['videos'];

    if (streams is List && streams.isNotEmpty) {
      final preferred = _qualityParam;
      Map<String, dynamic>? defaultRow;
      Map<String, dynamic>? firstRow;

      for (final row in streams) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        firstRow ??= map;
        if (map['isDefault'] == true || '${map['default']}'.toLowerCase() == 'true') {
          defaultRow = map;
        }
        final quality = '${map['quality'] ?? map['resolution'] ?? map['label'] ?? ''}'.toLowerCase();
        if (preferred.isNotEmpty && quality.contains(preferred.replaceAll('p', ''))) {
          final url = _first(map, const [
            'url',
            'src',
            'videoUrl',
            'video_url',
            'hlsUrl',
            'hls_url',
            'mp4Url',
            'mp4_url',
            'playUrl',
            'play_url',
          ]);
          if (url.isNotEmpty) return url;
        }
      }

      final selected = preferred.isEmpty
          ? _lowestQualityRow(streams)
          : (defaultRow ?? firstRow);
      if (selected != null) {
        final url = _first(selected, const [
          'url',
          'src',
          'videoUrl',
          'video_url',
          'hlsUrl',
          'hls_url',
          'mp4Url',
          'mp4_url',
          'playUrl',
          'play_url',
        ]);
        if (url.isNotEmpty) return url;
      }
    }

    if (streams is Map) {
      final preferred = _qualityParam;
      if (preferred.isNotEmpty && streams[preferred] != null) return '${streams[preferred]}';
      for (final key in ['auto', 'default', '1080p', '720p', '480p', 'url']) {
        if (streams[key] != null) return '${streams[key]}';
      }
    }

    return _first(data, const [
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
      'cdnUrl',
      'cdn_url',
      'mediaUrl',
      'media_url',
      'file',
      'link',
    ]);
  }



  static List<StreamQuality> _extractQualities(Map<String, dynamic> data) {
    final streams = data['qualityList'] ??
        data['quality_list'] ??
        data['streams'] ??
        data['qualities'] ??
        data['urls'] ??
        data['videos'];
    final rows = <StreamQuality>[];
    if (streams is List) {
      for (final row in streams) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final rawUrl = _first(map, const [
          'url',
          'src',
          'videoUrl',
          'video_url',
          'hlsUrl',
          'hls_url',
          'mp4Url',
          'mp4_url',
          'playUrl',
          'play_url',
        ]);
        if (rawUrl.isEmpty) continue;
        final label = _first(map, const [
          'label',
          'quality',
          'resolution',
          'name',
        ], fallback: 'Auto');
        rows.add(StreamQuality(
          label: label,
          url: _normalizePlayableUrl(rawUrl),
          isDefault: map['isDefault'] == true || '${map['default']}'.toLowerCase() == 'true',
        ));
      }
    }
    if (streams is Map) {
      for (final entry in streams.entries) {
        final rawUrl = '${entry.value}'.trim();
        if (rawUrl.isEmpty || rawUrl == 'null') continue;
        rows.add(StreamQuality(label: '${entry.key}', url: _normalizePlayableUrl(rawUrl)));
      }
    }
    return rows;
  }

  static Map<String, dynamic>? _lowestQualityRow(List streams) {
    Map<String, dynamic>? fallback;
    Map<String, dynamic>? lowest;
    var lowestHeight = 1 << 30;
    for (final row in streams) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      fallback ??= map;
      final label = '${map['quality'] ?? map['resolution'] ?? map['label'] ?? ''}';
      final match = RegExp(r'(\d{3,4})').firstMatch(label);
      final height = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
      if (height > 0 && height < lowestHeight) {
        lowestHeight = height;
        lowest = map;
      }
    }
    return lowest ?? fallback;
  }

  static String _normalizePlayableUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$baseUrl$url';
    return url;
  }

  static Map<String, dynamic>? _findEpisodeRow(Map<String, dynamic> json, int ep) {
    final rows = _episodeList(json);
    if (rows.isEmpty) return null;

    for (final row in rows) {
      final number = _parseInt(
        row['number'] ??
            row['episode'] ??
            row['episodeNumber'] ??
            row['episode_number'] ??
            row['ep'] ??
            row['index'],
        fallback: -1,
      );
      if (number == ep) return row;
    }

    final index = ep - 1;
    if (index >= 0 && index < rows.length) return rows[index];
    return null;
  }

  static void _appendSubtitles(
    List<SubtitleTrack> out,
    Object? raw, {
    required String fallbackLang,
  }) {
    if (raw is Map) {
      _appendSubtitles(out, raw['data'] ?? raw['items'] ?? raw['list'] ?? raw['tracks'] ?? raw['subtitles'], fallbackLang: fallbackLang);
      return;
    }
    if (raw is! List) return;

    for (final row in raw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final subUrl = _first(map, const [
        'url',
        'vttUrl',
        'vtt_url',
        'subtitleUrl',
        'subtitle_url',
        'src',
        'file',
        'link',
      ]);
      if (subUrl.isEmpty) continue;
      out.add(SubtitleTrack(
        language: _first(map, const [
          'language',
          'lang',
          'label',
          'name',
          'code',
        ], fallback: fallbackLang),
        format: subUrl.toLowerCase().contains('.srt') ? 'srt' : 'vtt',
        url: _normalizePlayableUrl(subUrl),
      ));
    }
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
