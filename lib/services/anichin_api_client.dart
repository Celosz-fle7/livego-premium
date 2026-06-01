import '../core/livego_settings.dart';
import 'api/api_endpoints.dart';
import 'api/api_env.dart';
import 'api/api_http_client.dart';
import 'api/api_platform.dart';
import '../models/content_item.dart';
import '../models/stream_info.dart';
import '../models/livego_episode.dart';

class AnichinApiClient {
  static String get baseUrl => ApiEnv.baseUrl;
  static String get apiKey => ApiEnv.apiKey;

  static List<String> get supportedPlatforms => LiveGoApiPlatforms.supportedSlugs;
  static List<String> get defaultPlatforms => LiveGoApiPlatforms.defaultSlugs;

  static bool supports(String platform) => LiveGoApiPlatforms.supports(platform);

  static String _apiSlug(String platform) => LiveGoApiPlatforms.normalizeSlug(platform);

  static Future<List<ContentItem>> home({
    String platform = 'shortmax',
    String lang = 'id',
  }) async {
    final slug = _apiSlug(platform);
    final apiLang = _providerLang(slug, lang);
    final json = await _getJson(ApiEndpoints.trending(slug), {
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

    // Melolo does not expose /foryou in the API summary; trending is documented
    // as the same feed family, so keep catalog browsing alive without 404 spam.
    if (slug == 'melolo') {
      return home(platform: platform, lang: apiLang);
    }

    final json = await _getJson(ApiEndpoints.forYou(slug), {
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
    final path = _collectionPath(slug, key);
    final json = await _getJson(path, {
      if (path.endsWith('/foryou')) 'page': '$page',
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
    final json = await _getJson(ApiEndpoints.search(slug), {
      _searchParam(slug): query.trim(),
      'lang': apiLang,
    });
    return _parseItems(json, platform: platform, lang: apiLang);
  }

  static Future<ContentItem?> detail(ContentItem item) async {
    final slug = _apiSlug(item.platformSlug);
    final apiLang = _providerLang(slug, item.lang);
    final json = await _getJson(ApiEndpoints.detail(slug), {
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
    final apiLang = _providerLang(slug, item.lang);

    Map<String, dynamic> json = <String, dynamic>{};
    try {
      json = await _getJson(ApiEndpoints.allEpisode(slug), {
        'id': item.id,
        'lang': apiLang,
      });
    } catch (_) {
      json = <String, dynamic>{};
    }

    var rows = _episodesFromJson(json);

    // ShortMax can be very fast for /episode, but the first player open must
    // still show the full playlist. If /allepisode returns an incomplete shape
    // or only a synthetic single row, fall back to /detail where ShortMax often
    // carries the complete episode metadata/count.
    if (rows.length <= 1 && slug == 'shortmax') {
      try {
        final detailJson = await _getJson(ApiEndpoints.detail(slug), {
          'id': item.id,
          'lang': apiLang,
        });
        final detailRows = _episodesFromJson(detailJson);
        if (detailRows.length > rows.length) rows = detailRows;

        final detailCount = _episodes(_dataMap(detailJson));
        if (rows.length <= 1 && detailCount > 1) {
          rows = _syntheticEpisodes(detailCount);
        }
      } catch (_) {
        // Keep the generic fallback below.
      }
    }

    if (rows.isNotEmpty) return rows;

    final total = item.episodes <= 0 ? 1 : item.episodes;
    return _syntheticEpisodes(total);
  }

  static List<LiveGoEpisode> _episodesFromJson(Map<String, dynamic> json) {
    final raw = _episodeList(json);
    if (raw.isEmpty) return const <LiveGoEpisode>[];
    return raw.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final row = entry.value;
      final number = _parseInt(
        row['number'] ?? row['episode'] ?? row['episodeNumber'] ?? row['episode_number'] ?? row['chapterNo'] ?? row['chapter_no'] ?? row['chapterIndex'] ?? row['chapter_index'] ?? row['ep'] ?? row['index'],
        fallback: idx,
      );
      final title = _first(row, const ['chapterName', 'chapter_name', 'title', 'name', 'episodeTitle', 'episode_title', 'chapterTitle', 'chapter_title'], fallback: 'Episode $number');
      return LiveGoEpisode(id: '$number', index: number, title: title);
    }).toList();
  }

  static List<LiveGoEpisode> _syntheticEpisodes(int total) {
    final safeTotal = total <= 0 ? 1 : total;
    return List.generate(safeTotal, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'));
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

    final config = LiveGoApiPlatforms.bySlug(slug);
    if (config.isEncrypted) {
      print('ANICHIN VIDEO UNSUPPORTED $slug ep=$ep: encrypted CENC/player endpoint not wired yet');
      return StreamInfo.empty;
    }

    Future<StreamInfo> resolveWithLang(String lang) async {
      final q = <String, String>{
        'id': playableId,
        'ep': '$ep',
        'lang': lang,
        if (_qualityParam.isNotEmpty) 'q': _qualityParam,
      };

      // Jangan anggap semua platform sama. DramaBox paling stabil dari
      // /allepisode karena response-nya memang membawa hlsUrl signed. FlickReels
      // dicoba dari /episode dulu, lalu /allepisode sebagai fallback.
      final attempts = <Future<StreamInfo> Function()>[];
      if (config.streamFromAllEpisodes) {
        attempts.add(() => _streamFromAllEpisodes(item, ep: ep, slug: slug, lang: lang));
        attempts.add(() => _streamFromEpisodeEndpoint(item, query: q, ep: ep, slug: slug, lang: lang));
      } else {
        attempts.add(() => _streamFromEpisodeEndpoint(item, query: q, ep: ep, slug: slug, lang: lang));
        attempts.add(() => _streamFromAllEpisodes(item, ep: ep, slug: slug, lang: lang));
      }
      attempts.add(() => _streamFromDetailEpisode(item, ep: ep, slug: slug, lang: lang));

      for (final attempt in attempts) {
        final stream = await attempt();
        if (stream.url.isNotEmpty) return stream;
      }
      return StreamInfo.empty;
    }

    final stream = await resolveWithLang(apiLang);
    if (stream.url.isNotEmpty) return stream;

    final fallbackLang = _fallbackStreamLang(slug, apiLang);
    if (fallbackLang != apiLang) {
      final fallback = await resolveWithLang(fallbackLang);
      if (fallback.url.isNotEmpty) return fallback;
    }

    return StreamInfo.empty;
  }


  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) async {
    final slug = _apiSlug(item.platformSlug);
    final apiLang = _providerLang(slug, item.lang);
    final chapter = '${chapterId ?? item.chapterId}';
    final ep = _episodeNumber(chapter);
    final playableId = item.id.trim();
    if (playableId.isEmpty) {
      print('ANICHIN FAST EP EMPTY ID ${item.platformSlug} ep=$ep title=${item.title}');
      return StreamInfo.empty;
    }

    final query = <String, String>{
      'id': playableId,
      'ep': '$ep',
      'lang': apiLang,
      if (_qualityParam.isNotEmpty) 'q': _qualityParam,
    };

    final config = LiveGoApiPlatforms.bySlug(slug);
    if (config.isEncrypted) {
      print('ANICHIN FAST EP UNSUPPORTED $slug ep=$ep: encrypted CENC/player endpoint not wired yet');
      return StreamInfo.empty;
    }

    Future<StreamInfo> tryEpisode() async {
      try {
        final json = await _getJson(ApiEndpoints.episode(slug), query).timeout(timeout);
        if (json.isEmpty) return StreamInfo.empty;
        return _parseFastStream(json, item: item, ep: ep, slug: slug, lang: apiLang);
      } catch (e) {
        print('ANICHIN FAST EP STREAM EMPTY $slug ep=$ep: $e');
        return StreamInfo.empty;
      }
    }

    Future<StreamInfo> tryAllEpisodes() async {
      try {
        return await _streamFromAllEpisodes(item, ep: ep, slug: slug, lang: apiLang)
            .timeout(timeout, onTimeout: () => StreamInfo.empty);
      } catch (e) {
        print('ANICHIN FAST ALLEP STREAM EMPTY $slug ep=$ep: $e');
        return StreamInfo.empty;
      }
    }

    final attempts = config.streamFromAllEpisodes
        ? <Future<StreamInfo> Function()>[tryAllEpisodes, tryEpisode]
        : <Future<StreamInfo> Function()>[tryEpisode, tryAllEpisodes];

    for (final attempt in attempts) {
      final stream = await attempt();
      if (stream.url.isNotEmpty) return stream;
    }

    final fallbackLang = _fallbackStreamLang(slug, apiLang);
    if (fallbackLang != apiLang) {
      final fallbackQuery = <String, String>{
        'id': playableId,
        'ep': '$ep',
        'lang': fallbackLang,
        if (_qualityParam.isNotEmpty) 'q': _qualityParam,
      };
      try {
        final json = await _getJson(ApiEndpoints.episode(slug), fallbackQuery).timeout(timeout);
        final stream = await _parseFastStream(json, item: item, ep: ep, slug: slug, lang: fallbackLang);
        if (stream.url.isNotEmpty) return stream;
      } catch (e) {
        print('ANICHIN FAST FALLBACK LANG EP EMPTY $slug ep=$ep lang=$fallbackLang: $e');
      }
      try {
        final stream = await _streamFromAllEpisodes(item, ep: ep, slug: slug, lang: fallbackLang)
            .timeout(timeout, onTimeout: () => StreamInfo.empty);
        if (stream.url.isNotEmpty) return stream;
      } catch (e) {
        print('ANICHIN FAST FALLBACK LANG ALL EMPTY $slug ep=$ep lang=$fallbackLang: $e');
      }
    }

    return StreamInfo.empty;
  }


  static Future<StreamInfo> _parseFastStream(
    Map<String, dynamic> json, {
    required ContentItem item,
    required int ep,
    required String slug,
    required String lang,
  }) {
    return _parseStream(json, item: item, ep: ep, slug: slug, lang: lang);
  }

  static Future<StreamInfo> _streamFromEpisodeEndpoint(
    ContentItem item, {
    required Map<String, String> query,
    required int ep,
    required String slug,
    required String lang,
  }) async {
    try {
      final json = await _getJson(ApiEndpoints.episode(slug), query);
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
      final all = await _getJson(ApiEndpoints.allEpisode(slug), {
        'id': item.id,
        'lang': lang,
      });
      final row = _findEpisodeRow(all, ep);
      if (row == null) {
        final direct = await _parseStream(all, item: item, ep: ep, slug: slug, lang: lang);
        return direct.url.isNotEmpty ? direct : StreamInfo.empty;
      }
      return _parseStream(row, item: item, ep: ep, slug: slug, lang: lang);
    } catch (e) {
      print('ANICHIN ALLEPISODE STREAM EMPTY $slug ep=$ep: $e');
      return StreamInfo.empty;
    }
  }

  static Future<StreamInfo> _streamFromDetailEpisode(
    ContentItem item, {
    required int ep,
    required String slug,
    required String lang,
  }) async {
    try {
      final detail = await _getJson(ApiEndpoints.detail(slug), {
        'id': item.id,
        'lang': lang,
      });
      final row = _findEpisodeRow(detail, ep);
      if (row != null) {
        final parsed = await _parseStream(row, item: item, ep: ep, slug: slug, lang: lang);
        if (parsed.url.isNotEmpty) return parsed;
      }

      // Beberapa provider mengembalikan stream episode aktif langsung di detail.
      final direct = await _parseStream(detail, item: item, ep: ep, slug: slug, lang: lang);
      return direct.url.isNotEmpty ? direct : StreamInfo.empty;
    } catch (e) {
      print('ANICHIN DETAIL STREAM EMPTY $slug ep=$ep: $e');
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


  static String _fallbackStreamLang(String slug, String current) {
    final config = LiveGoApiPlatforms.bySlug(slug);
    if (slug == 'netshort' && current != 'in' && config.supportedLangs.contains('in')) return 'in';
    if (current != 'id' && config.supportedLangs.contains('id')) return 'id';
    if (current != 'en' && config.supportedLangs.contains('en')) return 'en';
    return current;
  }

  static String _providerLang(String slug, String requested) {
    return LiveGoApiPlatforms.langFor(slug, requested);
  }

  static String _collectionPath(String slug, String key) {
    return ApiEndpoints.collection(slug, key);
  }

  static String _searchParam(String slug) {
    return LiveGoApiPlatforms.bySlug(slug).searchParam;
  }

  static String get _qualityParam {
    final q = LiveGoSettings.quality.toLowerCase();
    if (q.contains('1080')) return '1080p';
    if (q.contains('720')) return '720p';
    if (q.contains('480')) return '480p';
    return '';
  }

  static Future<Map<String, dynamic>> _getJson(String path, Map<String, String> query) {
    return ApiHttpClient.getJson(path, query);
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
    // Provider Anichin beda-beda bungkus episode list. Parser ini sengaja
    // luas supaya DramaBox/FlickReels/NetShort tidak jatuh ke Episode 1 palsu.
    Object? data = json['episodes'] ??
        json['episodeList'] ??
        json['episode_list'] ??
        json['episodeInfoList'] ??
        json['episode_info_list'] ??
        json['chapters'] ??
        json['chapterList'] ??
        json['chapter_list'] ??
        json['playList'] ??
        json['play_list'] ??
        json['list'] ??
        json['items'] ??
        json['rows'] ??
        json['data'];

    while (data is Map) {
      final next = data['episodes'] ??
          data['episodeList'] ??
          data['episode_list'] ??
          data['episodeInfoList'] ??
          data['episode_info_list'] ??
          data['chapters'] ??
          data['chapterList'] ??
          data['chapter_list'] ??
          data['playList'] ??
          data['play_list'] ??
          data['list'] ??
          data['items'] ??
          data['rows'] ??
          data['data'];
      if (identical(next, data) || next == null) break;
      data = next;
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
        final subJson = await _getJson(ApiEndpoints.subtitles('dramabox'), {
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
    final candidates = <Map<String, dynamic>>[];

    void addCandidate(Object? value) {
      if (value is! Map) return;
      final map = Map<String, dynamic>.from(value);
      candidates.add(map);
      for (final key in const [
        'data',
        'result',
        'episode',
        'episodeInfo',
        'episode_info',
        'video',
        'stream',
        'play',
        'playInfo',
        'play_info',
        'media',
        'source',
        'resource',
        'chapter',
      ]) {
        addCandidate(map[key]);
      }
    }

    addCandidate(data);

    for (final c in candidates) {
      if (_extractUrl(c).isNotEmpty) return c;
    }
    return data;
  }

  static const List<String> _playableUrlKeys = [
    'url',
    'src',
    'videoUrl',
    'video_url',
    'playUrl',
    'play_url',
    'mp4Url',
    'mp4_url',
    'hlsUrl',
    'hls_url',
    'm3u8',
    'm3u8Url',
    'm3u8_url',
    'streamUrl',
    'stream_url',
    'cdnUrl',
    'cdn_url',
    'mediaUrl',
    'media_url',
    'file',
    'link',
  ];

  static String _playableUrlFromMap(Map<String, dynamic> data) {
    return _first(data, _playableUrlKeys);
  }

  static bool _looksPlayableUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url == 'null') return false;
    final low = url.toLowerCase();
    return low.startsWith('http://') ||
        low.startsWith('https://') ||
        low.startsWith('/') ||
        low.contains('.mp4') ||
        low.contains('.m3u8') ||
        low.contains('/hls') ||
        low.contains('video') ||
        low.contains('cdn');
  }

  static String _deepPlayableUrl(Object? value) {
    if (value is String) {
      final clean = value.trim();
      return _looksPlayableUrl(clean) ? clean : '';
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final direct = _playableUrlFromMap(map);
      if (direct.isNotEmpty) return direct;
      for (final entry in map.entries) {
        final key = '${entry.key}'.toLowerCase();
        if (key.contains('subtitle') || key.contains('cover') || key.contains('poster') || key.contains('image')) {
          continue;
        }
        final nested = _deepPlayableUrl(entry.value);
        if (nested.isNotEmpty) return nested;
      }
    }
    if (value is List) {
      for (final row in value) {
        final nested = _deepPlayableUrl(row);
        if (nested.isNotEmpty) return nested;
      }
    }
    return '';
  }

  static String _extractUrl(Map<String, dynamic> data) {
    final streams = data['qualityList'] ??
        data['quality_list'] ??
        data['streamList'] ??
        data['stream_list'] ??
        data['sourceList'] ??
        data['source_list'] ??
        data['videoList'] ??
        data['video_list'] ??
        data['playList'] ??
        data['play_list'] ??
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
        final quality = '${map['quality'] ?? map['resolution'] ?? map['label'] ?? map['name'] ?? ''}'.toLowerCase();
        if (preferred.isNotEmpty && quality.contains(preferred.replaceAll('p', ''))) {
          final url = _playableUrlFromMap(map).isNotEmpty
              ? _playableUrlFromMap(map)
              : _deepPlayableUrl(map);
          if (url.isNotEmpty) return url;
        }
      }

      final selected = preferred.isEmpty
          ? _lowestQualityRow(streams)
          : (defaultRow ?? firstRow);
      if (selected != null) {
        final url = _playableUrlFromMap(selected).isNotEmpty
            ? _playableUrlFromMap(selected)
            : _deepPlayableUrl(selected);
        if (url.isNotEmpty) return url;
      }
    }

    if (streams is Map) {
      final preferred = _qualityParam;
      if (preferred.isNotEmpty && streams[preferred] != null) {
        return _deepPlayableUrl(streams[preferred]);
      }
      for (final key in const ['auto', 'default', '1080p', '720p', '480p', 'url', 'hlsUrl', 'videoUrl']) {
        if (streams[key] != null) {
          final url = _deepPlayableUrl(streams[key]);
          if (url.isNotEmpty) return url;
        }
      }
      final any = _deepPlayableUrl(streams);
      if (any.isNotEmpty) return any;
    }

    final direct = _playableUrlFromMap(data);
    if (direct.isNotEmpty) return direct;
    return _deepPlayableUrl(data);
  }


  static List<StreamQuality> _extractQualities(Map<String, dynamic> data) {
    final streams = data['qualityList'] ??
        data['quality_list'] ??
        data['streamList'] ??
        data['stream_list'] ??
        data['sourceList'] ??
        data['source_list'] ??
        data['videoList'] ??
        data['video_list'] ??
        data['playList'] ??
        data['play_list'] ??
        data['streams'] ??
        data['qualities'] ??
        data['urls'] ??
        data['videos'];
    final rows = <StreamQuality>[];
    if (streams is List) {
      for (final row in streams) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final rawUrl = _playableUrlFromMap(map).isNotEmpty
            ? _playableUrlFromMap(map)
            : _deepPlayableUrl(map);
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
        final rawUrl = _deepPlayableUrl(entry.value).trim();
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
            row['chapterNo'] ??
            row['chapter_no'] ??
            row['chapterIndex'] ??
            row['chapter_index'] ??
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
      final known = raw['data'] ?? raw['items'] ?? raw['list'] ?? raw['tracks'] ?? raw['subtitles'];
      if (known != null) {
        _appendSubtitles(out, known, fallbackLang: fallbackLang);
        return;
      }
      // NetShort/DramaBox kadang bisa berupa {"id": "url", "en": "url"}.
      for (final entry in raw.entries) {
        final key = '${entry.key}'.trim();
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty && value.trim() != 'null') {
          out.add(SubtitleTrack(
            language: key.isEmpty ? fallbackLang : key,
            format: value.toLowerCase().contains('.srt') ? 'srt' : 'vtt',
            url: _normalizePlayableUrl(value),
          ));
        } else if (value is Map || value is List) {
          _appendSubtitles(out, value, fallbackLang: key.isEmpty ? fallbackLang : key);
        }
      }
      return;
    }
    if (raw is! List) return;

    for (final row in raw) {
      if (row is String && row.trim().isNotEmpty) {
        out.add(SubtitleTrack(
          language: fallbackLang,
          format: row.toLowerCase().contains('.srt') ? 'srt' : 'vtt',
          url: _normalizePlayableUrl(row),
        ));
        continue;
      }
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final subUrl = _first(map, const [
        'url',
        'vttUrl',
        'vtt_url',
        'subtitleUrl',
        'subtitle_url',
        'subtitlesUrl',
        'subtitles_url',
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
        json['chapterList'] ??
        json['chapter_list'] ??
        json['episodeList'] ??
        json['episode_list'] ??
        json['episodeInfoList'] ??
        json['episode_info_list'] ??
        json['total_episodes'] ??
        json['totalEpisodes'] ??
        json['episodeCount'] ??
        json['episode_count'] ??
        json['episodes'];
    if (raw is List) return raw.length;
    final rows = _episodeList(json);
    if (rows.isNotEmpty) return rows.length;
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
