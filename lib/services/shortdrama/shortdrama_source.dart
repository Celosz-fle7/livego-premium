import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'shortdrama_client.dart';
import 'shortdrama_config.dart';
import 'shortdrama_filters.dart';

/// Adapter ShortDrama TV sebagai DramaSource di LiveGo.
///
/// Alur (hasil reverse engineering APK com.shortdramatv.rlles):
///   1. /api/channel/get_list   -> tab bawaan
///   2. /api/search/screen      -> feed besar (20 item) per kategori
///   3. /api/vod_short/list_new -> short drama + show_collection_play_url
///   4. series_hash + bahasa diambil dari play_url -> path episode
///   5. URL video di-sign sendiri: md5(key + path + wsTimeHex)
///
/// Catatan server: request anonim mengabaikan filter & paginasi
/// (channel/get_info dan topic/vod_list butuh login), jadi konten
/// digabung dari beberapa endpoint agar kategori tidak kosong.
class ShortDramaSource implements DramaSource {
  final ShortDramaClient _client = ShortDramaClient.instance;

  /// channel_name (label Indonesia) -> channel_id.
  final Map<String, int> _channelIds = {};

  /// seriesId -> series_hash (dari show_collection_play_url).
  final Map<String, String> _seriesHash = {};

  /// seriesId -> bahasa audio di CDN ('id' / 'es'), dari play_url.
  final Map<String, String> _seriesLang = {};

  /// seriesId -> total episode.
  final Map<String, int> _seriesTotal = {};

  /// seriesId -> URL subtitle (srt) kalau ada.
  final Map<String, String> _seriesSubtitle = {};

  /// "$seriesId:$episodeId" -> signed stream URL.
  final Map<String, String> _streamCache = {};

  /// Cache hasil per kategori (server lambat & hasilnya statis).
  final Map<String, List<ContentItem>> _categoryCache = {};

  bool _channelsLoaded = false;

  /// Sesi device: muat token tersimpan, lalu pastikan token valid.
  bool _sessionReady = false;

  static const String _prefToken = 'shortdrama_token';
  static const String _prefUserId = 'shortdrama_user_id';

  @override
  String get slug => 'shortdrama';

  @override
  String get label => 'ShortDrama';

  /// Kategori dari server (channel list) kalau sudah dimuat,
  /// fallback ke hardcoded kalau server belum merespon.
  /// Urutan: server order (urutan tampil asli dari server).
  @override
  List<String> get categories {
    if (_serverCategories.isNotEmpty) return _serverCategories;
    return ShortDramaConfig.categories;
  }

  /// Kategori dari server (channel list), dimuat via _ensureChannels().
  final List<String> _serverCategories = [];

  /// Ambil kategori dari server (channel list).
  /// Dipakai UI untuk refresh tab setelah channel dimuat.
  Future<List<String>> fetchServerCategories() async {
    await _ensureChannels();
    if (_serverCategories.isNotEmpty) return _serverCategories;
    return ShortDramaConfig.categories;
  }

  /// Muat token dari SharedPreferences (biar awet antar sesi) lalu
  /// pastikan token valid via /api/public/init.
  ///
  /// TIDAK PERNAH melempar exception: kegagalan login tidak boleh
  /// mengosongkan feed (request tetap dicoba tanpa token).
  Future<void> _ensureSession() async {
    if (_sessionReady) return;
    _sessionReady = true; // set lebih dulu agar tidak dobel
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefToken);
      if (saved != null && saved.isNotEmpty) {
        _client.setToken(saved);
      }
    } catch (_) {}
    try {
      await _client.ensureLogin();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_client.token.isNotEmpty) {
        await prefs.setString(_prefToken, _client.token);
      }
      if (_client.userId.isNotEmpty) {
        await prefs.setString(_prefUserId, _client.userId);
      }
    } catch (_) {}
  }

  /// Muat daftar channel dari server sekali, isi _channelIds + _serverCategories.
  /// Kategori diambil ORI dari server (urutan tampil server), bukan hardcoded.
  Future<void> _ensureChannels() async {
    if (_channelsLoaded) return;
    await _ensureSession();
    try {
      final list = await _client.channelList();
      final seen = <String>{};
      for (final c in list) {
        final id = c['id'];
        final name = '${c['channel_name'] ?? ''}'.toLowerCase().trim();
        if (id is int) {
          final label = ShortDramaConfig.channelNameMap[name] ?? name;
          _channelIds[label] = id;
          // Kategori dari server, urutan sesuai server, tanpa duplikat.
          if (label.isNotEmpty && seen.add(label)) {
            _serverCategories.add(label);
          }
        }
      }
      _channelsLoaded = true;
    } catch (_) {
      // biarkan; kategori fallback ke agregasi endpoint
    }
  }

  /// Daftarkan series (hash + bahasa + total + subtitle) dari item API mentah.
  void _registerFromRaw(List<Map<String, dynamic>> raw) {
    for (final m in raw) {
      final id = '${m['id'] ?? m['vod_id'] ?? ''}';
      if (id.isEmpty) continue;
      final playUrl = '${m['show_collection_play_url'] ?? ''}';
      final hash = extractSeriesHash(playUrl);
      final lang = extractSeriesLang(playUrl);
      final total = int.tryParse('${m['vod_total'] ?? m['vod_serial'] ?? 0}') ?? 0;
      final srt = '${m['show_collection_srt_url'] ?? ''}';
      if (hash.isNotEmpty) _seriesHash[id] = hash;
      if (lang.isNotEmpty) _seriesLang[id] = lang;
      if (total > 0) _seriesTotal[id] = total;
      if (srt.isNotEmpty) _seriesSubtitle[id] = srt;
    }
  }

  /// Pilih filter server sesuai nama kategori.
  /// audience: Femenino/Masculino, background: Moderno/Fantasía/Histórico,
  /// sort: hot/new. Server anonim kadang mengabaikan, tapi tetap dikirim
  /// supaya kalau nanti login, hasilnya sudah benar.
  ({String? audience, String? background, String? sort}) _filterFor(String category) {
    switch (category) {
      case 'Wanita':
        return (audience: 'Femenino', background: null, sort: null);
      case 'Pria':
        return (audience: 'Masculino', background: null, sort: null);
      case 'Peringkat':
        return (audience: null, background: null, sort: 'hot');
      case 'Rilis Baru':
        return (audience: null, background: null, sort: 'new');
      default:
        return (audience: null, background: null, sort: null);
    }
  }

  /// Ambil konten satu kategori dari beberapa endpoint, gabung tanpa duplikat.
  ///
  /// PENTING: hanya item dengan `show_collection_play_url` yang bisa diputar
  /// (item dari screen/hot_search tidak punya hash dan endpoint detail butuh
  /// login). Item tanpa play_url dibuang supaya tidak error saat diklik.
  Future<List<ContentItem>> _fetchCategory(String category) async {
    final cached = _categoryCache[category];
    if (cached != null) return cached;

    // Muat channel dari server dulu (kategori ori + session).
    await _ensureChannels();

    final seen = <String>{};
    final out = <ContentItem>[];
    final filter = _filterFor(category);

    void addRaw(List<Map<String, dynamic>> raw) {
      if (raw.isEmpty) return;
      _registerFromRaw(raw);
      for (final m in raw) {
        final id = '${m['id'] ?? m['vod_id'] ?? ''}';
        if (id.isEmpty) continue;
        if (!_seriesHash.containsKey(id)) continue; // hanya yang playable
        if (!seen.add(id)) continue;
        final items = _client.mapAll([m], category);
        if (items.isNotEmpty) out.add(items.first);
      }
    }

    // Jalankan semua endpoint PARALEL. Kalau berurutan, total waktu bisa
    // melewati timeout home (10s) dan feed jadi kosong.
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _safe(() => _client.vodShortNewRaw()),
      _safe(() => _client.newbieTopRaw()),
      _safe(() => _client.screenRaw(
            page: 1,
            pageSize: 20,
            audience: filter.audience,
            background: filter.background,
            sort: filter.sort,
          )),
      _safe(() => _client.hotSearchRaw()),
    ]);

    for (final raw in results) {
      addRaw(raw);
    }

    // Kategori "Sulih Suara": server tidak menyediakan channel dubbing yang
    // bisa diakses anonim, jadi filter di client (nama bertanda
    // Doblado/Dublado atau tag menyebut sulih suara/indonesia).
    var finalItems = out;
    if (category == 'Sulih Suara') {
      finalItems = ShortDramaFilters.dubbedOnly(out);
    }

    if (finalItems.isNotEmpty) _categoryCache[category] = finalItems;
    return finalItems;
  }

  /// Jalankan request, kembalikan list kosong kalau gagal.
  static Future<List<Map<String, dynamic>>> _safe(
    Future<List<Map<String, dynamic>>> Function() run,
  ) async {
    try {
      return await run();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    final res = await homePage(category, page: 1, pageSize: 30);
    return res.items;
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final all = await _fetchCategory(category);
    if (all.isEmpty) return (items: <ContentItem>[], hasMore: false);

    // Server anonim tidak mendukung paginasi -> potong lokal.
    final start = (page - 1) * pageSize;
    if (start >= all.length) return (items: <ContentItem>[], hasMore: false);
    final end = (start + pageSize).clamp(0, all.length);
    return (items: all.sublist(start, end), hasMore: end < all.length);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    // ShortDrama tidak punya endpoint episode terpisah untuk short drama:
    // jumlah episode = vod_total, path berpola {ep}.mp4.
    final total = _seriesTotal[seriesId] ?? 0;
    final count = total > 0 ? total : 1;
    return List<LiveGoEpisode>.generate(
      count,
      (i) => LiveGoEpisode(
        id: '${i + 1}',
        index: i + 1,
        title: 'Episode ${i + 1}',
      ),
    );
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final key = '$seriesId:$episodeId';
    final cached = _streamCache[key];
    if (cached != null && cached.isNotEmpty) return cached;

    final hash = _seriesHash[seriesId];
    if (hash == null || hash.isEmpty) {
      throw Exception('ShortDrama: series_hash tidak dikenal ($seriesId)');
    }

    final lang = _seriesLang[seriesId] ?? ShortDramaConfig.videoLang;
    final ep = int.tryParse(episodeId) ?? 1;
    final path = '/series/$hash/translated/$lang/$ep.mp4';
    final url = signVideoUrl(path);
    _streamCache[key] = url;
    return url;
  }

  /// Sign URL video CDN (nginx secure_link style).
  /// wsSecret = md5(key + path + wsTimeHex); wsTime = hex(unix seconds).
  static String signVideoUrl(String path, {DateTime? at}) {
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final wsTime = ts.toRadixString(16);
    final wsSecret = md5
        .convert(utf8.encode('${ShortDramaConfig.videoSignKey}$path$wsTime'))
        .toString();
    return '${ShortDramaConfig.cdnBase}$path?wsSecret=$wsSecret&wsTime=$wsTime';
  }

  /// Ambil series_hash dari URL play (segmen setelah /series/).
  static String extractSeriesHash(String playUrl) {
    const marker = '/series/';
    final idx = playUrl.indexOf(marker);
    if (idx < 0) return '';
    final rest = playUrl.substring(idx + marker.length);
    final slash = rest.indexOf('/');
    return slash < 0 ? rest : rest.substring(0, slash);
  }

  /// Ambil bahasa audio dari URL play: /series/{hash}/translated/{lang}/{ep}.mp4
  static String extractSeriesLang(String playUrl) {
    const marker = '/translated/';
    final idx = playUrl.indexOf(marker);
    if (idx < 0) return '';
    final rest = playUrl.substring(idx + marker.length);
    final slash = rest.indexOf('/');
    final lang = slash < 0 ? rest : rest.substring(0, slash);
    return lang.trim();
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    await _ensureSession();
    final raw = await _client.searchRaw(query);
    _registerFromRaw(raw);
    return _client.mapAll(raw, 'Pencarian');
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(String seriesId, String episodeId) async {
    final lang = _seriesLang[seriesId] ?? ShortDramaConfig.videoLang;
    final srt = _seriesSubtitle[seriesId];

    final subtitles = <DramaSubtitle>[];
    if (srt != null && srt.isNotEmpty) {
      subtitles.add(DramaSubtitle(
        language: lang,
        displayName: _langName(lang),
        url: srt,
      ));
    }

    return DramaEpisodeExtras(
      subtitles: subtitles,
      // CDN hanya menyediakan satu berkas MP4 (tanpa varian 720p/1080p).
      qualities: const [DramaQuality(label: 'AUTO', resolution: 'auto')],
      // "Audio track" = bahasa audio yang tersedia di CDN.
      audioLanguages: [_langName(lang)],
      unlocked: true,
    );
  }

  static String _langName(String code) {
    switch (code) {
      case 'id':
        return 'Indonesia';
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      default:
        return code.toUpperCase();
    }
  }

  @override
  Future<void> signOut() async {
    _streamCache.clear();
    _categoryCache.clear();
    _sessionReady = false;
    _client.setToken('');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefToken);
      await prefs.remove(_prefUserId);
    } catch (_) {}
  }
}
