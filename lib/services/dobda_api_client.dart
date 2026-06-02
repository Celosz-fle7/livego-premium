import 'dart:convert';
import 'dart:io';

import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'api/api_env.dart';
import 'api/api_platform.dart';
import 'api/dobda_endpoints.dart';
import 'api/dobda_hmac_signer.dart';

class DobdaApiClient {
  const DobdaApiClient._();

  static String get baseUrl => ApiEnv.dobdaBaseUrl;
  static final Map<String, List<LiveGoEpisode>> _episodeMemory = <String, List<LiveGoEpisode>>{};


  static Future<List<ContentItem>> home({
    String platform = 'dobda_freereels',
    String lang = 'id',
  }) async {
    return homeFeed(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'dobda_freereels',
    String lang = 'id',
    int page = 1,
  }) async {
    return homeFeed(platform: platform, lang: lang, page: page);
  }

  static Future<List<ContentItem>> collection({
    String platform = 'dobda_freereels',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) async {
    final key = LiveGoApiPlatforms.categoryKey(platform, collection);
    if (key == 'livego' || key == 'indonesia' || key == 'dubindo') {
      return liveGoFeed(platform: platform, lang: lang, page: page);
    }
    return homeFeed(platform: platform, lang: lang, page: page);
  }

  static Future<List<ContentItem>> homeFeed({
    String platform = 'dobda_freereels',
    String lang = 'id',
    int page = 1,
  }) async {
    final results = await Future.wait<List<ContentItem>>([
      _safeRows(_homeRaw(platform: platform, lang: lang), '$platform/home'),
      _safeRows(_discoverRaw(platform: platform, lang: lang, page: page), '$platform/discover'),
    ]);

    final merged = <ContentItem>[];
    final seen = <String>{};

    for (final rows in results) {
      for (final item in rows) {
        // Home Dobda jangan diisi video Dub/Sulih. Konten dub khusus masuk LiveGo.
        if (!_isCleanDobdaItem(item, excludeDubbed: true)) continue;
        final key = _contentKey(item);
        if (seen.add(key)) merged.add(item);
      }
    }

    return merged.take(60).toList();
  }

  static Future<List<ContentItem>> liveGoFeed({
    String platform = 'dobda_freereels',
    String lang = 'id',
    int page = 1,
  }) async {
    final results = await Future.wait<List<ContentItem>>([
      _safeRows(_searchRaw(query: 'dub', platform: platform, lang: lang, page: page), '$platform/livego-dub'),
      _safeRows(_searchRaw(query: 'dubbing', platform: platform, lang: lang, page: page), '$platform/livego-dubbing'),
      _safeRows(_searchRaw(query: 'sulih', platform: platform, lang: lang, page: page), '$platform/livego-sulih'),
    ]);

    final merged = <ContentItem>[];
    final seen = <String>{};

    for (final rows in results) {
      for (final item in rows) {
        if (!_isCleanDobdaItem(item, requireDubbed: true)) continue;
        final key = _contentKey(item);
        if (seen.add(key)) merged.add(item);
      }
    }

    return merged.take(60).toList();
  }

  // Migrasi aman untuk setting/cache lama yang masih menyimpan kategori Indonesia.
  static Future<List<ContentItem>> indonesiaFeed({
    String platform = 'dobda_freereels',
    String lang = 'id',
    int page = 1,
  }) async {
    return liveGoFeed(platform: platform, lang: lang, page: page);
  }

  static Future<List<ContentItem>> banner({
    String platform = 'dobda_freereels',
    String lang = 'id',
  }) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);
    final json = await _getJson(DobdaEndpoints.banner, {
      'category_p': config.apiSlug,
      'lang': apiLang,
    });
    return _parseItems(json, platform: config.slug, lang: apiLang);
  }

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'dobda_freereels',
    String lang = 'id',
    int page = 1,
  }) async {
    final rows = await _searchRaw(query: query, platform: platform, lang: lang, page: page);
    return _cleanDobdaItems(rows, fromDubSearch: true);
  }

  static Future<List<ContentItem>> _safeRows(
    Future<List<ContentItem>> future,
    String label,
  ) async {
    try {
      return await future.timeout(const Duration(seconds: 6));
    } catch (e) {
      print('DOBDA CLEAN FEED ERROR $label: $e');
      return const <ContentItem>[];
    }
  }

  static Future<List<ContentItem>> _homeRaw({
    required String platform,
    required String lang,
  }) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);
    final json = await _getJson(DobdaEndpoints.home, {
      'category_p': config.apiSlug,
      'lang': apiLang,
    });
    return _parseItems(json, platform: config.slug, lang: apiLang);
  }

  static Future<List<ContentItem>> _discoverRaw({
    required String platform,
    required String lang,
    int page = 1,
  }) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);
    final json = await _getJson(DobdaEndpoints.discover, {
      'category_p': config.apiSlug,
      'lang': apiLang,
      'page': '$page',
      'limit': '20',
    });
    return _parseItems(json, platform: config.slug, lang: apiLang);
  }

  static Future<List<ContentItem>> _searchRaw({
    required String query,
    required String platform,
    required String lang,
    int page = 1,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return const <ContentItem>[];
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);

    Future<List<ContentItem>> run(String param) async {
      final json = await _getJson(DobdaEndpoints.search, {
        'category_p': config.apiSlug,
        param: clean,
        'lang': apiLang,
        'page': '$page',
        'limit': '20',
      });
      return _parseItems(json, platform: config.slug, lang: apiLang);
    }

    final byQ = await run('q');
    if (byQ.isNotEmpty) return byQ;
    return run('query');
  }

  static Future<ContentItem?> detail(ContentItem item) async {
    final config = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final apiLang = _providerLang(config.slug, item.lang);
    final json = await _getJson(DobdaEndpoints.detail, {
      'category_p': config.apiSlug,
      'id': item.id,
      'lang': apiLang,
    });
    final data = _dataMap(json);
    if (data.isEmpty) return item;

    final rows = _episodesFromJson(json);
    if (rows.isNotEmpty) {
      _episodeMemory[_episodeKey(item, apiLang)] = rows;
    }

    final parsed = _parseItem(data, platform: config.slug, lang: apiLang);
    return _preserveIdentity(parsed, fallback: item, lang: apiLang);
  }

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async {
    final config = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final apiLang = _providerLang(config.slug, item.lang);
    final key = _episodeKey(item, apiLang);
    final cached = _episodeMemory[key];
    if (cached != null && cached.length > 1) return cached;

    final json = await _getJson(DobdaEndpoints.detail, {
      'category_p': config.apiSlug,
      'id': item.id,
      'lang': apiLang,
    });
    final rows = _episodesFromJson(json);
    if (rows.isNotEmpty) {
      _episodeMemory[key] = rows;
      return rows;
    }

    final total = _episodes(_dataMap(json));
    final fallback = List.generate(total <= 0 ? item.episodes : total, (i) {
      return LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}');
    });
    _episodeMemory[key] = fallback;
    return fallback;
  }

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) async {
    final config = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final apiLang = _providerLang(config.slug, item.lang);
    final ep = _episodeNumber(chapterId ?? item.chapterId);
    final requested = (chapterId ?? item.chapterId).trim().isEmpty ? '$ep' : (chapterId ?? item.chapterId).trim();
    final requestedIsEpisodeNumber = RegExp(r'^\d+$').hasMatch(requested);

    // Dobda /video membutuhkan chapterId asli dari /detail. Angka 1,2,3
    // tidak selalu aman sebagai chapterId di semua platform Dobda. Kalau
    // player meminta episode index, resolve dulu ke chapters[].id supaya
    // PREV/NEXT dan daftar episode tidak loncat ke video acak.
    if (requestedIsEpisodeNumber) {
      final mappedChapter = await _chapterIdForEpisode(
        item,
        config: config,
        apiLang: apiLang,
        episodeIndex: ep,
      );
      if (mappedChapter.isNotEmpty) {
        final mapped = await _tryVideoByChapter(
          item,
          config: config,
          apiLang: apiLang,
          chapterId: mappedChapter,
          episodeIndex: ep,
        );
        if (mapped.url.isNotEmpty) return mapped;
      }
    }

    final direct = await _tryVideoByChapter(
      item,
      config: config,
      apiLang: apiLang,
      chapterId: requested,
      episodeIndex: ep,
    );
    if (direct.url.isNotEmpty) return direct;

    if (!requestedIsEpisodeNumber) {
      final mappedChapter = await _chapterIdForEpisode(item, config: config, apiLang: apiLang, episodeIndex: ep);
      if (mappedChapter.isNotEmpty && mappedChapter != requested) {
        final mapped = await _tryVideoByChapter(
          item,
          config: config,
          apiLang: apiLang,
          chapterId: mappedChapter,
          episodeIndex: ep,
        );
        if (mapped.url.isNotEmpty) return mapped;
      }
    }

    return StreamInfo.empty;
  }

  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) async {
    final config = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final apiLang = _providerLang(config.slug, item.lang);
    final ep = _episodeNumber(chapterId ?? item.chapterId);
    final requested = (chapterId ?? item.chapterId).trim().isEmpty ? '$ep' : (chapterId ?? item.chapterId).trim();
    final requestedIsEpisodeNumber = RegExp(r'^\d+$').hasMatch(requested);

    // Root cause loncat episode Dobda: player TV mengirim episode index
    // (1,2,3...), sedangkan Dobda /video mengharapkan chapterId asli dari
    // /detail. Probe angka bisa berhasil di beberapa provider, tapi hasilnya
    // bukan selalu episode index yang diminta. Jadi untuk angka, selalu map
    // dulu ke chapters[].id dan jangan tembak angka mentah lebih dulu.
    if (requestedIsEpisodeNumber) {
      try {
        final mappedChapter = await _chapterIdForEpisode(
          item,
          config: config,
          apiLang: apiLang,
          episodeIndex: ep,
        ).timeout(_shorterTimeout(timeout, const Duration(seconds: 4)));
        if (mappedChapter.isNotEmpty) {
          final mapped = await _tryVideoByChapter(
            item,
            config: config,
            apiLang: apiLang,
            chapterId: mappedChapter,
            episodeIndex: ep,
            timeout: timeout,
          );
          if (mapped.url.isNotEmpty) return mapped;
        }
      } catch (e) {
        print('DOBDA FAST MAP EMPTY ${item.platformSlug} ep=$ep: $e');
      }

      // Fallback terakhir saja. Ini hanya untuk provider yang benar-benar
      // memakai chapterId sama dengan nomor episode.
      final direct = await _tryVideoByChapter(
        item,
        config: config,
        apiLang: apiLang,
        chapterId: requested,
        episodeIndex: ep,
        timeout: _shorterTimeout(timeout, const Duration(seconds: 3)),
      );
      if (direct.url.isNotEmpty) return direct;
      return StreamInfo.empty;
    }

    // Kalau sudah dikirim chapterId asli, langsung pakai. Ini dipakai ketika
    // fitur lain nanti mengirim row.id dari daftar episode.
    final direct = await _tryVideoByChapter(
      item,
      config: config,
      apiLang: apiLang,
      chapterId: requested,
      episodeIndex: ep,
      timeout: timeout,
    );
    if (direct.url.isNotEmpty) return direct;

    try {
      final mappedChapter = await _chapterIdForEpisode(
        item,
        config: config,
        apiLang: apiLang,
        episodeIndex: ep,
      ).timeout(_shorterTimeout(timeout, const Duration(seconds: 4)));
      if (mappedChapter.isEmpty || mappedChapter == requested) return StreamInfo.empty;
      return await _tryVideoByChapter(
        item,
        config: config,
        apiLang: apiLang,
        chapterId: mappedChapter,
        episodeIndex: ep,
        timeout: timeout,
      );
    } catch (e) {
      print('DOBDA FAST VIDEO EMPTY ${item.platformSlug} chapter=$chapterId: $e');
      return StreamInfo.empty;
    }
  }

  static Future<StreamInfo> _tryVideoByChapter(
    ContentItem item, {
    required LiveGoApiPlatform config,
    required String apiLang,
    required String chapterId,
    required int episodeIndex,
    Duration? timeout,
  }) async {
    try {
      var future = _getJson(DobdaEndpoints.video, {
        'category_p': config.apiSlug,
        'id': item.id,
        'chapterId': chapterId,
        'lang': apiLang,
      });
      if (timeout != null) future = future.timeout(timeout);
      final json = await future;
      final stream = _parseStream(json, item: item, fallbackEpisode: episodeIndex, lang: apiLang);
      if (stream.url.isEmpty) return StreamInfo.empty;
      return stream;
    } catch (e) {
      print('DOBDA VIDEO EMPTY ${config.slug} chapter=$chapterId ep=$episodeIndex: $e');
      return StreamInfo.empty;
    }
  }

  static Future<String> _chapterIdForEpisode(
    ContentItem item, {
    required LiveGoApiPlatform config,
    required String apiLang,
    required int episodeIndex,
  }) async {
    final key = _episodeKey(item, apiLang);
    var rows = _episodeMemory[key];
    rows ??= await episodes(item);
    if (rows.isEmpty) return '$episodeIndex';

    for (final row in rows) {
      if (row.index == episodeIndex && row.id.trim().isNotEmpty) return row.id.trim();
    }
    final pos = episodeIndex - 1;
    if (pos >= 0 && pos < rows.length && rows[pos].id.trim().isNotEmpty) {
      return rows[pos].id.trim();
    }
    return '$episodeIndex';
  }

  static Duration _shorterTimeout(Duration a, Duration b) {
    return a.inMilliseconds <= b.inMilliseconds ? a : b;
  }

  static String _episodeKey(ContentItem item, String lang) => '${item.platformSlug}:${item.id}:$lang';

  static Future<String> ping(String platform, String lang) async {
    final start = DateTime.now();
    try {
      final rows = await home(platform: platform, lang: lang).timeout(const Duration(seconds: 8));
      if (rows.isEmpty) return 'offline';
      final ms = DateTime.now().difference(start).inMilliseconds;
      return ms > 2500 ? 'slow' : 'online';
    } catch (_) {
      return 'offline';
    }
  }

  static Future<Map<String, dynamic>> _getJson(String path, Map<String, String> query) async {
    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(ApiEnv.timeout);
      final headers = DobdaHmacSigner.headers(
        method: 'GET',
        uri: uri,
        secret: ApiEnv.dobdaSecret,
      );
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final response = await request.close().timeout(ApiEnv.timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('DOBDA API ${response.statusCode} ${uri.path}: $body');
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

  static List<ContentItem> _cleanDobdaItems(
    List<ContentItem> rows, {
    bool fromDubSearch = false,
    bool requireDubbed = false,
    bool excludeDubbed = false,
  }) {
    final out = <ContentItem>[];
    final seen = <String>{};
    for (final item in rows) {
      if (!_isCleanDobdaItem(
        item,
        fromDubSearch: fromDubSearch,
        requireDubbed: requireDubbed,
        excludeDubbed: excludeDubbed,
      )) {
        continue;
      }
      final key = _contentKey(item);
      if (seen.add(key)) out.add(item);
    }
    return out;
  }

  static bool _isCleanDobdaItem(
    ContentItem item, {
    bool fromDubSearch = false,
    bool requireDubbed = false,
    bool excludeDubbed = false,
  }) {
    if (item.id.trim().isEmpty) return false;
    if (item.title.trim().isEmpty || item.title == 'Untitled') return false;
    if (item.posterUrl.trim().isEmpty || item.posterUrl.trim().endsWith('url=')) return false;
    if (item.episodes <= 0) return false;

    final dubbed = _isDubbed(item);
    if (excludeDubbed && dubbed) return false;
    if (requireDubbed) return dubbed;

    // Search biasa tetap boleh menampilkan hasil sesuai kata kunci user.
    if (fromDubSearch) return true;
    return true;
  }

  static String _contentKey(ContentItem item) => '${item.platformSlug}:${item.id}';

  static bool _isDubbed(ContentItem item) {
    final text = _searchBlob(item);
    return text.contains('(dub') ||
        text.contains(' dubbing') ||
        text.contains('[versi dub') ||
        text.contains('sulih suara') ||
        text.contains('sulih');
  }

  static bool _looksIndonesian(ContentItem item) {
    final text = ' ${_searchBlob(item)} ';
    const markers = [
      ' yang ',
      ' dan ',
      ' dengan ',
      ' setelah ',
      ' karena ',
      ' untuk ',
      ' dari ',
      ' jadi ',
      ' menjadi ',
      ' dalam ',
      ' adalah ',
      ' aku ',
      ' kamu ',
      ' dia ',
      ' tak ',
      ' tidak ',
      ' cinta ',
      ' keluarga ',
      ' suami ',
      ' istri ',
      ' anak ',
      ' bos ',
      ' tuan ',
      ' nona ',
      ' menikah ',
      ' pernikahan ',
      ' rahasia ',
      ' kembali ',
      ' sang ',
      ' balas ',
      ' dendam ',
      ' kuat ',
      ' kontrak ',
      ' sulih ',
      ' selesai ',
    ];
    return markers.any(text.contains);
  }

  static String _searchBlob(ContentItem item) {
    return '${item.title} ${item.description} ${item.category} ${item.source}'
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
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

  static ContentItem _parseItem(
    Map<String, dynamic> json, {
    required String platform,
    required String lang,
  }) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final id = _first(json, const ['id', 'bookId', 'book_id', 'dramaId', 'seriesId']);
    final title = _first(json, const ['title', 'name', 'bookName', 'dramaName'], fallback: 'Untitled');
    final cover = _first(json, const ['cover', 'poster', 'posterUrl', 'coverUrl', 'image', 'thumbnail']);
    final backdrop = _first(json, const ['backdrop', 'banner', 'cover', 'poster', 'image']);
    final description = _first(json, const ['synopsis', 'description', 'desc', 'summary']);
    final source = _first(json, const ['platform', 'source', 'author'], fallback: config.name);
    final episodes = _episodes(json);
    final firstChapter = _firstChapterId(json);

    return ContentItem(
      id: id,
      title: title,
      source: source.isEmpty ? config.name : source,
      category: _category(json),
      description: description,
      posterUrl: cover,
      backdropUrl: backdrop.isEmpty ? cover : backdrop,
      rating: 8.0,
      episodes: episodes <= 0 ? 1 : episodes,
      updated: true,
      platformSlug: config.slug,
      chapterId: firstChapter.isEmpty ? '1' : firstChapter,
      lang: lang,
    );
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

  static StreamInfo _parseStream(
    Map<String, dynamic> json, {
    required ContentItem item,
    required int fallbackEpisode,
    required String lang,
  }) {
    final data = _dataMap(json);
    final streams = data['streams'];
    final qualities = <StreamQuality>[];
    String url = '';

    if (streams is List) {
      for (final row in streams) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final rawUrl = _first(map, const ['url', 'src', 'videoUrl', 'hlsUrl', 'streamUrl']);
        if (rawUrl.isEmpty) continue;
        final label = _first(map, const ['quality', 'resolution', 'label', 'name'], fallback: 'Auto');
        qualities.add(StreamQuality(label: label.isEmpty ? 'Auto' : label, url: _normalizeUrl(rawUrl)));
      }
      if (qualities.isNotEmpty) url = qualities.first.url;
    }

    if (url.isEmpty) {
      final direct = _first(data, const ['url', 'src', 'videoUrl', 'hlsUrl', 'streamUrl']);
      if (direct.isNotEmpty) url = _normalizeUrl(direct);
    }

    final subtitles = <SubtitleTrack>[];
    _appendSubtitles(subtitles, data['subtitles'] ?? data['subtitle'], fallbackLang: lang);

    final total = _parseInt(data['total_episodes'] ?? data['totalEpisodes'] ?? item.episodes, fallback: item.episodes);
    final episodeIndex = _parseInt(data['episode_index'] ?? data['episodeIndex'] ?? fallbackEpisode, fallback: fallbackEpisode);

    final headers = <String, String>{
      'User-Agent': 'okhttp/4.12.0',
      'Accept': '*/*',
    };
    final streamHeaders = data['streamHeaders'] ?? data['headers'];
    if (streamHeaders is Map) {
      for (final entry in streamHeaders.entries) {
        final key = '${entry.key}'.trim();
        final value = '${entry.value}'.trim();
        if (key.isNotEmpty && value.isNotEmpty && value != 'null') {
          headers[key] = value;
        }
      }
    }

    return StreamInfo(
      url: url,
      episodeIndex: episodeIndex,
      totalEpisodes: total <= 0 ? item.episodes : total,
      nextEpisodeId: '${data['next_video_id'] ?? data['nextVideoId'] ?? (episodeIndex < total ? episodeIndex + 1 : 0)}',
      prevEpisodeId: '${data['prev_video_id'] ?? data['prevVideoId'] ?? (episodeIndex > 1 ? episodeIndex - 1 : 0)}',
      headers: headers,
      subtitles: subtitles,
      qualities: qualities,
    );
  }

  static List<LiveGoEpisode> _episodesFromJson(Map<String, dynamic> json) {
    final rows = _episodeList(json);
    if (rows.isEmpty) return const <LiveGoEpisode>[];
    final parsed = rows.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final row = entry.value;
      final index = _parseInt(
        row['index'] ?? row['episode_index'] ?? row['episodeIndex'] ?? row['episode'] ?? row['number'] ?? row['chapterNo'] ?? row['chapter_no'],
        fallback: idx,
      );
      final safeIndex = index <= 0 ? idx : index;
      final id = _first(row, const ['id', 'chapterId', 'chapter_id', 'videoId', 'video_id'], fallback: '$safeIndex');
      final title = _first(row, const ['title', 'name', 'chapterName', 'chapter_name'], fallback: 'Episode $safeIndex');
      return LiveGoEpisode(id: id, index: safeIndex, title: title);
    }).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final unique = <LiveGoEpisode>[];
    final seen = <int>{};
    for (final row in parsed) {
      if (seen.add(row.index)) unique.add(row);
    }
    return unique;
  }

  static List<Map<String, dynamic>> _dataList(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map) {
      final nested = data['items'] ?? data['list'] ?? data['results'] ?? data['rows'] ?? data['data'];
      if (nested is List) return nested.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    for (final key in const ['items', 'list', 'results', 'rows']) {
      final value = json[key];
      if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _dataMap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static List<Map<String, dynamic>> _episodeList(Map<String, dynamic> json) {
    Object? data = _dataMap(json);
    while (data is Map) {
      final next = data['chapters'] ?? data['episodes'] ?? data['episodeList'] ?? data['chapterList'];
      if (next == null || identical(next, data)) break;
      data = next;
    }
    if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const <Map<String, dynamic>>[];
  }

  static void _appendSubtitles(List<SubtitleTrack> out, Object? raw, {required String fallbackLang}) {
    if (raw is Map) {
      final known = raw['data'] ?? raw['items'] ?? raw['list'] ?? raw['tracks'] ?? raw['subtitles'];
      if (known != null) {
        _appendSubtitles(out, known, fallbackLang: fallbackLang);
        return;
      }
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          out.add(SubtitleTrack(
            language: '${entry.key}'.trim().isEmpty ? fallbackLang : '${entry.key}',
            format: value.toLowerCase().contains('.srt') ? 'srt' : 'webvtt',
            url: _normalizeUrl(value),
          ));
        }
      }
      return;
    }
    if (raw is! List) return;
    for (final row in raw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final subUrl = _first(map, const ['url', 'vttUrl', 'subtitleUrl', 'src', 'file']);
      if (subUrl.isEmpty) continue;
      out.add(SubtitleTrack(
        language: _first(map, const ['language', 'lang', 'label', 'name'], fallback: fallbackLang),
        format: _first(map, const ['format'], fallback: subUrl.toLowerCase().contains('.srt') ? 'srt' : 'webvtt'),
        url: _normalizeUrl(subUrl),
      ));
    }
  }

  static String _firstChapterId(Map<String, dynamic> json) {
    final chapters = json['chapters'];
    if (chapters is List && chapters.isNotEmpty && chapters.first is Map) {
      return _first(Map<String, dynamic>.from(chapters.first), const ['id', 'chapterId', 'chapter_id']);
    }
    return '';
  }

  static String _category(Map<String, dynamic> json) {
    final genres = json['genres'] ?? json['genre'] ?? json['categories'] ?? json['tags'];
    if (genres is List && genres.isNotEmpty) {
      for (final raw in genres) {
        final first = '$raw'.trim();
        if (first.isNotEmpty && first != 'null') {
          return first.split(',').first.trim().isEmpty ? first : first.split(',').first.trim();
        }
      }
    }
    if (genres is String && genres.trim().isNotEmpty) return genres.trim().split(',').first.trim();
    return 'Drama';
  }

  static int _episodes(Map<String, dynamic> json) {
    final raw = json['chapters'] ?? json['total_episodes'] ?? json['totalEpisodes'] ?? json['episodes'];
    if (raw is List) return raw.length;
    final parsed = _parseInt(raw, fallback: 1);
    return parsed <= 0 ? 1 : parsed;
  }

  static String _providerLang(String slug, String requested) {
    return LiveGoApiPlatforms.langFor(slug, requested);
  }

  static int _episodeNumber(String chapter) {
    final direct = int.tryParse(chapter);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'\d+').firstMatch(chapter);
    final parsed = match == null ? null : int.tryParse(match.group(0)!);
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }

  static String _normalizeUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$baseUrl$url';
    return url;
  }

  static String _first(Map<String, dynamic> json, List<String> keys, {String fallback = ''}) {
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
