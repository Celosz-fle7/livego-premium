
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../api/api_env.dart';
import '../api/api_platform.dart';
import '../api/dobda_endpoints.dart';
import 'dobda_http_client.dart';

class DobdaApiClientImpl {
  const DobdaApiClientImpl._();

  static String get baseUrl => ApiEnv.baseUrl;
  static final Map<String, List<LiveGoEpisode>> _episodeMemory =
      <String, List<LiveGoEpisode>>{};

  static Future<List<ContentItem>> home({
    String platform = 'melolo',
    String lang = 'id',
  }) async {
    return homeFeed(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'melolo',
    String lang = 'id',
    int page = 1,
  }) async {
    final rows = await _safeRows(
      _discoverRaw(platform: platform, lang: lang, page: page),
      '$platform/discover',
    );
    return _cleanNobuzeroItems(rows).take(60).toList(growable: false);
  }

  static Future<List<ContentItem>> collection({
    String platform = 'melolo',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) async {
    LiveGoApiPlatforms.bySlug(platform);
    final key = LiveGoApiPlatforms.categoryKey(platform, collection);
    if (key == 'livego' || key == 'indonesia' || key == 'dubindo') {
      return liveGoFeed(platform: platform, lang: lang, page: page);
    }
    if (key == 'latest' || key == 'discover') {
      return discover(platform: platform, lang: lang, page: page);
    }
    if (key == 'trending' || key == 'home') {
      return homeFeed(platform: platform, lang: lang, page: page);
    }
    return search(query: _categorySearchQuery(key), platform: platform, lang: lang, page: page);
  }

  static Future<Map<String, List<String>>> categories({
    String platform = 'melolo',
    String lang = 'id',
  }) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);

    Map<String, dynamic> json;
    try {
      json = await DobdaHttpClient.getJson(DobdaEndpoints.categories, {
        'category_p': config.apiSlug,
        'lang': apiLang,
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      print('LiveGO API CATEGORIES PLATFORM EMPTY ${config.slug}: $e');
      json = await DobdaHttpClient.getJson(DobdaEndpoints.categories, const <String, String>{})
          .timeout(const Duration(seconds: 6));
    }

    final parsed = _parseCategories(json);
    if (parsed.isEmpty) return const <String, List<String>>{};

    final normalized = <String, List<String>>{};
    for (final entry in parsed.entries) {
      final slug = LiveGoApiPlatforms.bySlugOrNull(entry.key)?.slug ??
          LiveGoApiPlatforms.normalizeSlug(entry.key);
      final labels = _normalizeCategoryLabels(entry.value);
      if (labels.isNotEmpty) normalized[slug] = labels;
    }

    if (normalized.isEmpty) {
      final labels = _normalizeCategoryLabels(parsed.values.expand((e) => e));
      if (labels.isNotEmpty) normalized[config.slug] = labels;
    }
    return normalized;
  }

  static Future<List<ContentItem>> homeFeed({
    String platform = 'melolo',
    String lang = 'id',
    int page = 1,
  }) async {
    // TV Home must be fast. /home is the primary fast path and must not wait
    // for /discover. /discover is only a fallback if /home returns empty.
    final homeRows = await _safeRows(
      _homeRaw(platform: platform, lang: lang),
      '$platform/home',
    );
    final cleanHome = _cleanNobuzeroItems(homeRows, excludeDubbed: true);
    if (cleanHome.isNotEmpty) return cleanHome.take(60).toList(growable: false);

    final discoverRows = await _safeRows(
      _discoverRaw(platform: platform, lang: lang, page: page),
      '$platform/discover-fallback',
    );
    final cleanDiscover = _cleanNobuzeroItems(discoverRows, excludeDubbed: true);
    return cleanDiscover.take(60).toList(growable: false);
  }

  static Future<List<ContentItem>> liveGoFeed({
    String platform = 'melolo',
    String lang = 'id',
    int page = 1,
  }) async {
    const queries = <String>[
      'dub',
      'dubbing',
      'sulih',
      'indo',
      'sub indo',
      'id',
    ];

    final results = await Future.wait<List<ContentItem>>([
      for (final query in queries)
        _safeRows(
          _searchRaw(query: query, platform: platform, lang: lang, page: page),
          '$platform/livego-$query',
        ),
    ]);

    final merged = <ContentItem>[];
    final seen = <String>{};

    for (final rows in results) {
      for (final item in rows) {
        if (!_isCleanNobuzeroItem(item)) continue;
        if (!_isLiveGoRecommendation(item)) continue;
        final key = _contentKey(item);
        if (seen.add(key)) merged.add(item);
      }
    }

    return merged.take(60).toList();
  }

  // Migrasi aman untuk setting/cache lama yang masih menyimpan kategori Indonesia.
  static Future<List<ContentItem>> indonesiaFeed({
    String platform = 'melolo',
    String lang = 'id',
    int page = 1,
  }) async {
    return liveGoFeed(platform: platform, lang: lang, page: page);
  }

  static Future<List<ContentItem>> banner({
    String platform = 'melolo',
    String lang = 'id',
  }) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);
    try {
      final json = await DobdaHttpClient.getJson(DobdaEndpoints.banner, {
        'category_p': config.apiSlug,
        'lang': apiLang,
      });
      return _parseItems(json, platform: config.slug, lang: apiLang);
    } catch (e) {
      print('LiveGO API BANNER EMPTY ${config.slug}: $e');
      return const <ContentItem>[];
    }
  }

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'melolo',
    String lang = 'id',
    int page = 1,
  }) async {
    final rows = await _searchRaw(
      query: query,
      platform: platform,
      lang: lang,
      page: page,
    );
    return _cleanNobuzeroItems(rows, fromDubSearch: true);
  }

  static String _categorySearchQuery(String key) {
    switch (key) {
      case 'movie':
        return 'movie';
      case 'series':
        return 'series';
      case 'drama':
        return 'drama';
      case 'romance':
        return 'romance';
      case 'short':
        return 'short';
    }
    return key;
  }

  static Future<List<ContentItem>> _safeRows(
    Future<List<ContentItem>> future,
    String label,
  ) async {
    try {
      return await future.timeout(const Duration(seconds: 6));
    } catch (e) {
      print('LiveGO API FEED ERROR $label: $e');
      return const <ContentItem>[];
    }
  }

  static Future<List<ContentItem>> _homeRaw({
    required String platform,
    required String lang,
  }) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);
    print('LIVEGO_API_REQ endpoint=/home platform=$platform');
    final json = await DobdaHttpClient.getJson(DobdaEndpoints.home, {
      'category_p': config.apiSlug,
      'lang': apiLang,
    });
    final items = _parseItems(json, platform: config.slug, lang: apiLang);
    print('LIVEGO_API_RESP endpoint=/home count=${items.length}');
    return items;
  }

  static Future<List<ContentItem>> _discoverRaw({
    required String platform,
    required String lang,
    int page = 1,
  }) async {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final apiLang = _providerLang(config.slug, lang);
    print('LIVEGO_API_REQ endpoint=/discover platform=$platform');
    final json = await DobdaHttpClient.getJson(DobdaEndpoints.discover, {
      'category_p': config.apiSlug,
      'lang': apiLang,
      'sort': 'desc',
      'page': '$page',
    });
    final items = _parseItems(json, platform: config.slug, lang: apiLang);
    print('LIVEGO_API_RESP endpoint=/discover count=${items.length}');
    return items;
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
      final json = await DobdaHttpClient.getJson(DobdaEndpoints.search, {
        'category_p': config.apiSlug,
        param: clean,
        'lang': apiLang,
        'page': '$page',
      });
      return _parseItems(json, platform: config.slug, lang: apiLang);
    }

    return run('q');
  }

  static Future<ContentItem?> detail(ContentItem item) async {
    final config = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final apiLang = _providerLang(config.slug, item.lang);
    final json = await DobdaHttpClient.getJson(DobdaEndpoints.detail, {
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
    if (config.slug == 'freereels') {
      print('LIVEGO_FREEREELS_DETAIL id=${item.id} chapters=${rows.length}');
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

    final json = await DobdaHttpClient.getJson(DobdaEndpoints.detail, {
      'category_p': config.apiSlug,
      'id': item.id,
      'lang': apiLang,
    });
    final rows = _episodesFromJson(json);
    if (rows.isNotEmpty) {
      _episodeMemory[key] = rows;
      return rows;
    }

    print('LIVEGO_API_EMPTY platform=${item.platformSlug} endpoint=/detail id=${item.id}');
    return const <LiveGoEpisode>[];
  }

  static Future<StreamInfo> videoInfo(ContentItem item,
      {String? chapterId}) async {
    final config = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final apiLang = _providerLang(config.slug, item.lang);
    final ep = _episodeNumber(chapterId ?? item.chapterId);

    // Filter chapterId: kalau kosong atau '1' tapi episodes > 1, coba resolve dulu.
    var requested = (chapterId ?? item.chapterId).trim();
    if (requested.isEmpty && item.episodes > 1) {
      requested = ''; // Biar diresolve di bawah
    }

    final requestedIsEpisodeNumber =
        requested.isEmpty || RegExp(r'^\d+$').hasMatch(requested);

    if (requestedIsEpisodeNumber) {
      final mappedChapter = await _chapterIdForEpisode(
        item,
        config: config,
        apiLang: apiLang,
        episodeIndex: ep,
      );
      if (mappedChapter.isNotEmpty && !RegExp(r'^\d+$').hasMatch(mappedChapter)) {
        final mapped = await _tryVideoByChapter(
          item,
          config: config,
          apiLang: apiLang,
          chapterId: mappedChapter,
          episodeIndex: ep,
        );
        if (mapped.url.isNotEmpty) return mapped;
      }

      // Jika mappedChapter masih angka, ini mungkin memang format ID-nya angka.
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

    if (requested.isNotEmpty) {
      final direct = await _tryVideoByChapter(
        item,
        config: config,
        apiLang: apiLang,
        chapterId: requested,
        episodeIndex: ep,
      );
      if (direct.url.isNotEmpty) return direct;
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

    // Root cause loncat episode Nobuzero: player TV mengirim episode index
    // (1,2,3...), sedangkan Nobuzero /video mengharapkan chapterId asli dari
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
        print('LiveGO API FAST MAP EMPTY ${item.platformSlug} ep=$ep: $e');
      }

      // Jangan asal tembak angka kalau tidak yakin itu chapterId.
      // Kecuali kalau mappedChapter memang angka dari API.
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
      print('LiveGO API FAST VIDEO EMPTY ${item.platformSlug} chapter=$chapterId: $e');
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
      print('LIVEGO_VIDEO_REQ id=${item.id} chapterId=$chapterId');
      Future<Map<String, dynamic>> future = DobdaHttpClient.getJson(DobdaEndpoints.video, {
        'category_p': config.apiSlug,
        'id': item.id,
        'chapterId': chapterId,
        'lang': apiLang,
      });
      if (timeout != null) future = future.timeout(timeout);
      final json = await future;
      final stream = _parseStream(json,
          item: item, fallbackEpisode: episodeIndex, lang: apiLang);

      final host = stream.url.isNotEmpty ? Uri.parse(stream.url).host : '';
      final path = stream.url.isNotEmpty ? Uri.parse(stream.url).path : '';
      final tail = path.length > 30 ? path.substring(path.length - 30) : path;
      print('LIVEGO_VIDEO_RESP url_empty=${stream.url.isEmpty} host=$host tail=$tail');

      if (stream.url.isEmpty) return StreamInfo.empty;
      return stream;
    } catch (e) {
      print(
          'LiveGO API VIDEO EMPTY ${config.slug} chapter=$chapterId ep=$episodeIndex: $e');
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
    if (rows.isEmpty) return '';

    for (final row in rows) {
      if (row.index == episodeIndex && row.id.trim().isNotEmpty) {
        return row.id.trim();
      }
    }
    final pos = episodeIndex - 1;
    if (pos >= 0 && pos < rows.length && rows[pos].id.trim().isNotEmpty) {
      return rows[pos].id.trim();
    }
    return '';
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

  static List<ContentItem> _cleanNobuzeroItems(
    List<ContentItem> rows, {
    bool fromDubSearch = false,
    bool requireDubbed = false,
    bool excludeDubbed = false,
  }) {
    final out = <ContentItem>[];
    final seen = <String>{};
    var filtered = 0;
    for (final item in rows) {
      if (!_isCleanNobuzeroItem(
        item,
        fromDubSearch: fromDubSearch,
        requireDubbed: requireDubbed,
        excludeDubbed: excludeDubbed,
      )) {
        filtered += 1;
        continue;
      }
      final key = _contentKey(item);
      if (seen.add(key)) {
        out.add(item);
      } else {
        filtered += 1;
      }
    }
    if (rows.any((item) => item.platformSlug == 'freereels')) {
      print(
          'LIVEGO_FREEREELS_FILTER in=${rows.length} out=${out.length} filtered=$filtered');
    }
    return out;
  }

  static bool _isCleanNobuzeroItem(
    ContentItem item, {
    bool fromDubSearch = false,
    bool requireDubbed = false,
    bool excludeDubbed = false,
  }) {
    if (item.id.trim().isEmpty) {
      return false;
    }
    if (item.title.trim().isEmpty ||
        item.title == 'Untitled' ||
        item.title.contains('Sample Drama')) {
      return false;
    }
    // Temporary Nobuzero compatibility: generated FreeReels test rows can
    // legitimately point at server-side placeholder covers while upstream
    // artwork is still being hydrated. Keep rejecting empty/broken poster URLs,
    // but do not reject URLs only because they contain `placeholder`.
    if (item.posterUrl.trim().isEmpty ||
        item.posterUrl.trim().endsWith('url=')) {
      return false;
    }
    if (item.episodes <= 0) {
      return false;
    }

    final dubbed = _isDubbed(item);
    if (excludeDubbed && dubbed) {
      return false;
    }
    if (requireDubbed) {
      return dubbed;
    }

    // Search biasa tetap boleh menampilkan hasil sesuai kata kunci user.
    if (fromDubSearch) return true;
    return true;
  }

  static String _contentKey(ContentItem item) => '${item.platformSlug}:${item.id}';

  static bool _isLiveGoRecommendation(ContentItem item) {
    final text = ' ${_searchBlob(item)} ';
    return _isDubbed(item) ||
        _looksIndonesian(item) ||
        text.contains(' sub indo ') ||
        text.contains(' subtitle indonesia ') ||
        text.contains(' bahasa indonesia ') ||
        text.contains(' indo ') ||
        text.contains('[id]') ||
        text.contains('(id)');
  }

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
      ' sub indo ',
      ' bahasa indonesia ',
      ' indonesia ',
      ' indo ',
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
    final id = _first(json, const [
      'source_id',
      'sourceId',
      'livego_id',
      'livegoId',
      'id',
      'bookId',
      'book_id',
      'dramaId',
      'seriesId',
      'movieId',
      'contentId'
    ]);
    final title = _first(json, const [
      'title',
      'name',
      'bookName',
      'dramaName',
      'movieName',
      'seriesName'
    ], fallback: 'Untitled');
    final cover = _first(json, const [
      'cover',
      'poster',
      'posterUrl',
      'coverUrl',
      'image',
      'thumbnail',
      'poster_path',
      'imageUrl'
    ]);

    print('LIVEGO_API_ITEM title=$title id=$id poster_empty=${cover.isEmpty}');

    final backdrop = _first(json, const [
      'backdrop',
      'banner',
      'cover',
      'poster',
      'image',
      'bannerUrl'
    ]);
    final description = _first(
        json, const ['synopsis', 'description', 'desc', 'summary', 'intro']);
    final source = _first(json, const ['platform', 'source', 'author'],
        fallback: config.name);
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
      episodes: episodes <= 0 ? 0 : episodes,
      updated: true,
      platformSlug: config.slug,
      chapterId: firstChapter,
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
        final rawUrl = _first(map, const [
          'url',
          'playUrl',
          'videoUrl',
          'm3u8',
          'hls',
          'streamUrl',
          'source',
          'src'
        ]);
        if (rawUrl.isEmpty) continue;
        final label = _first(map, const ['quality', 'resolution', 'label', 'name'],
            fallback: 'Auto');
        qualities.add(StreamQuality(
            label: label.isEmpty ? 'Auto' : label, url: _normalizeUrl(rawUrl)));
      }
      if (qualities.isNotEmpty) url = qualities.first.url;
    }

    if (url.isEmpty) {
      final direct = _first(data, const [
        'play_url',
        'playUrl',
        'url',
        'video_url',
        'videoUrl',
        'stream_url',
        'streamUrl',
        'm3u8',
        'hls',
        'source',
        'src'
      ]);
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
    final streamHeaders =
        data['headers'] ?? data['streamHeaders'] ?? data['requestHeaders'];
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
      final id = _first(row,
          const ['id', 'chapterId', 'chapter_id', 'episodeId', 'eid', 'videoId', 'video_id'],
          fallback: '$safeIndex');
      final title = _first(row,
          const ['title', 'name', 'chapterName', 'chapter_name'],
          fallback: 'Episode $safeIndex');
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

  static Map<String, List<String>> _parseCategories(Map<String, dynamic> json) {
    final out = <String, List<String>>{};

    void add(String platform, Object? raw) {
      final labels = _categoryNames(raw);
      if (labels.isEmpty) return;
      final key = platform.trim().isEmpty ? 'global' : platform.trim().toLowerCase();
      out[key] = <String>{
        ...?out[key],
        ...labels,
      }.toList(growable: false);
    }

    void walk(Object? node, {String platform = ''}) {
      if (node is List) {
        if (node.every((e) => e is String || e is num)) {
          add(platform, node);
          return;
        }
        for (final item in node) {
          walk(item, platform: platform);
        }
        return;
      }
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);

      final platformKey = _first(map, const ['platform', 'platform_slug', 'platformSlug', 'category_p', 'source', 'slug']);
      final scopedPlatform = platformKey.isNotEmpty && LiveGoApiPlatforms.bySlugOrNull(platformKey) != null
          ? LiveGoApiPlatforms.bySlug(platformKey).slug
          : platform;
      for (final key in const ['categories', 'items', 'list', 'data', 'results', 'rows']) {
        final value = map[key];
        if (value != null) walk(value, platform: scopedPlatform);
      }
      final single = _first(map, const ['label', 'name', 'title', 'category']);
      if (single.isNotEmpty) add(scopedPlatform, <String>[single]);

      for (final entry in map.entries) {
        final key = entry.key.toString().trim();
        if (const {'data', 'categories', 'items', 'list', 'results', 'rows'}
            .contains(key)) {
          continue;
        }
        if (LiveGoApiPlatforms.bySlugOrNull(key) != null) {
          add(key, entry.value);
        }
      }
    }

    walk(json['data'] ?? json);
    final direct = json['categories'];
    if (direct != null) walk(direct);
    return out;
  }

  static List<String> _categoryNames(Object? raw) {
    final labels = <String>[];
    void addText(Object? value) {
      final text = '$value'.trim();
      if (text.isEmpty || text == 'null') return;
      if (!labels.contains(text)) labels.add(text);
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          addText(_first(map, const ['label', 'name', 'title', 'category', 'slug']));
        } else {
          addText(item);
        }
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.value is List || entry.value is Map) {
          labels.addAll(_categoryNames(entry.value));
        } else {
          addText(entry.value);
        }
      }
    } else if (raw != null) {
      addText(raw);
    }
    return labels;
  }

  static List<String> _normalizeCategoryLabels(Iterable<String> values) {
    final labels = <String>[];
    for (final raw in values) {
      final label = LiveGoApiPlatforms.categoryLabel('melolo', raw);
      if (label.trim().isEmpty) continue;
      if (!labels.contains(label)) labels.add(label);
    }
    return labels.take(6).toList(growable: false);
  }

  static List<Map<String, dynamic>> _episodeList(Map<String, dynamic> json) {
    Object? data = _dataMap(json);
    while (data is Map) {
      final next = data['chapters'] ??
          data['chapterList'] ??
          data['episodes'] ??
          data['episodeList'] ??
          data['list'];
      if (next == null || identical(next, data)) break;
      data = next;
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
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
    final chapters = _episodeList(json);
    if (chapters.isNotEmpty) {
      return _first(Map<String, dynamic>.from(chapters.first),
          const ['id', 'chapterId', 'chapter_id', 'episodeId', 'eid']);
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
    final chapters = json['chapters'] ??
        json['chapterList'] ??
        json['episodes'] ??
        json['episodeList'] ??
        json['list'];
    if (chapters is List) return chapters.length;

    final raw = json['episode_count'] ??
        json['total_episodes'] ??
        json['totalEpisodes'] ??
        json['episodeCount'] ??
        json['chapterCount'] ??
        json['episodes'];
    final parsed = _parseInt(raw, fallback: 0);
    return parsed;
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
