import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/content_item.dart';
import 'shortdrama_config.dart';
import 'shortdrama_crypto.dart';

/// HTTP client ShortDrama TV — meniru persis request APK.
///
/// - Base: https://oyrg6c.1x6e0.top
/// - Request: POST JSON plaintext + header sign (MD5 salt+deviceId+time)
/// - Response: Base64(AES-256-CBC) -> didekripsi via ShortDramaCrypto
class ShortDramaClient {
  ShortDramaClient._();
  static final ShortDramaClient instance = ShortDramaClient._();

  String _deviceId = ShortDramaConfig.defaultDeviceId;
  final String _host = ShortDramaConfig.baseUrl;
  String _token = '';
  String _userId = '';

  /// Waktu token didapat (untuk refresh berkala).
  DateTime? _tokenAt;

  /// Token dianggap perlu refresh setelah durasi ini.
  /// Server bisa expire token tiap jam, jadi TTL 1 jam + refresh
  /// otomatis saat server bilang expired (code 21007).
  static const Duration _tokenTtl = Duration(hours: 1);

  /// Device ID unik per device, persisten di SharedPreferences.
  /// Dibuat sekali saat pertama install, awet antar restart.
  /// Kalau masih pakai default hardcoded, semua HP dianggap 1 device
  /// oleh server -> konflik sesi, 1 HP dapat konten, 1 HP kosong.
  static const String _prefDeviceId = 'shortdrama_device_id';

  /// Muat device ID persisten, atau buat baru kalau belum ada.
  /// Dipanggil sebelum login pertama.
  ///
  /// SELALU dijalankan (bukan cuma saat masih default): kalau device_id
  /// sudah pernah dimuat dari prefs, cukup return cepat.
  Future<void> _ensureDeviceId() async {
    if (_deviceIdLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var saved = prefs.getString(_prefDeviceId);
      if (saved == null || saved.isEmpty) {
        // Generate 16 byte random -> 32 hex char, seperti FreeReels.
        final rnd = math.Random.secure();
        final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
        saved = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await prefs.setString(_prefDeviceId, saved);
      }
      _deviceId = saved;
      _deviceIdLoaded = true;
    } catch (_) {
      // Fallback: pakai default kalau SharedPreferences gagal.
    }
  }

  /// Device ID sudah dimuat dari prefs?
  bool _deviceIdLoaded = false;

  String get host => _host;
  String get deviceId => _deviceId;
  String get token => _token;
  String get userId => _userId;

  void setDeviceId(String id) {
    final clean = id.trim();
    if (clean.isNotEmpty) _deviceId = clean;
  }

  /// Set token dari penyimpanan (restore sesi lama).
  ///
  /// PENTING: token hasil restore TIDAK dianggap fresh — `_tokenAt` sengaja
  /// dikosongkan supaya `ensureLogin()` tetap jalan dan memastikan
  /// device_id unik + token valid dari server. Kalau token lama dianggap
  /// fresh, login tidak pernah jalan, device_id tetap default (hardcoded),
  /// dan semua HP bentrok jadi satu device -> konten kosong.
  void setToken(String token) {
    _token = token.trim();
    _tokenAt = null;
  }

  /// Future login yang sedang berjalan (cegah login dobel bersamaan).
  Future<void>? _loginInFlight;

  /// Pastikan punya token device yang valid.
  ///
  /// Meniru APK: token didapat otomatis dari POST /api/public/init
  /// (user_info.token, login_type=0 = device login). Token di-refresh
  /// kalau belum ada, sudah lewat TTL, atau server bilang expired.
  ///
  /// Device ID SELALU dipastikan lebih dulu — kalau tidak, device_id tetap
  /// default (hardcoded) dan semua HP bentrok jadi satu device.
  Future<void> ensureLogin({bool force = false}) async {
    await _ensureDeviceId();

    final hasToken = _token.isNotEmpty && _tokenAt != null;
    final fresh = hasToken && DateTime.now().difference(_tokenAt!) < _tokenTtl;
    if (!force && fresh) return;

    // Sudah ada login berjalan -> tunggu yang itu, jangan mulai baru.
    final inFlight = _loginInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _doLogin();
    _loginInFlight = future;
    try {
      await future;
    } finally {
      _loginInFlight = null;
    }
  }

  Future<void> _doLogin() async {
    try {
      // Pastikan device ID unik per device sebelum login.
      await _ensureDeviceId();
      final res = await post(
        ShortDramaConfig.epInit,
        {'gaid': _deviceId, 'idfa': '', 'invitedby': '', 'referer': ''},
        skipAuth: true,
      );
      final info = (res['result'] as Map?)?['user_info'];
      if (info is Map) {
        final t = '${info['token'] ?? ''}'.trim();
        if (t.isNotEmpty) {
          _token = t;
          _tokenAt = DateTime.now();
        }
        final uid = '${info['user_id'] ?? ''}'.trim();
        if (uid.isNotEmpty) _userId = uid;
      }
    } catch (_) {
      // biarkan; request berikutnya tetap dicoba tanpa token
    }
  }

  /// sign = MD5(salt + deviceId + curTimeMs).toUpperCase()
  static String buildSign(String deviceId, int curTimeMs) {
    final raw = '${ShortDramaConfig.signSalt}$deviceId$curTimeMs';
    return md5.convert(utf8.encode(raw)).toString().toUpperCase();
  }

  Map<String, String> _headers() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return {
      'app_id': ShortDramaConfig.appId,
      'channel_code': ShortDramaConfig.channelCode,
      'cur_time': '$ts',
      'device_id': _deviceId,
      'mob_mfr': ShortDramaConfig.mobManufacturer,
      'mobmodel': ShortDramaConfig.mobModel,
      'package_name': ShortDramaConfig.packageName,
      'sign': buildSign(_deviceId, ts),
      'sysrelease': ShortDramaConfig.sysRelease,
      'version': ShortDramaConfig.versionCode,
      'sys_platform': ShortDramaConfig.sysPlatform,
      'language_id': ShortDramaConfig.languageId,
      'language_code': ShortDramaConfig.languageCode,
      'timezone_id': ShortDramaConfig.timezoneId,
      'timezone_name': ShortDramaConfig.timezoneName,
      'resolution': ShortDramaConfig.resolution,
      'token': _token,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// POST ke path, dekripsi response, kembalikan Map JSON.
  ///
  /// [skipAuth] = true untuk endpoint init (jangan panggil ensureLogin,
  /// hindari rekursi).
  /// Kalau server bilang token expired (code 21007 / pesan login),
  /// token di-refresh sekali lalu request diulang.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool skipAuth = false,
    bool retried = false,
  }) async {
    if (!skipAuth) await ensureLogin();

    final uri = Uri.parse('$_host$path');
    final client = HttpClient();
    client.connectionTimeout = ShortDramaConfig.timeout;
    try {
      final request = await client.postUrl(uri).timeout(ShortDramaConfig.timeout);
      _headers().forEach(request.headers.set);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(ShortDramaConfig.timeout);
      final raw = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('ShortDrama ${response.statusCode} $path: ${raw.trim()}');
      }

      final text = raw.trim();
      if (text.isEmpty) return <String, dynamic>{};

      // Response terenkripsi Base64(AES). Kalau bukan Base64 valid,
      // server mengirim pesan error plaintext.
      final plain = ShortDramaCrypto.decryptResponse(
        text,
        key: ShortDramaConfig.aesKey,
        iv: ShortDramaConfig.aesIv,
      );
      if (plain.isEmpty) {
        throw Exception('ShortDrama decrypt gagal $path: ${text.substring(0, text.length.clamp(0, 120))}');
      }
      final decoded = jsonDecode(plain);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : (decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{'result': decoded});

      // Token expired -> refresh sekali lalu ulang.
      if (!skipAuth && !retried && _isTokenExpired(map)) {
        await ensureLogin(force: true);
        return post(path, body, skipAuth: skipAuth, retried: true);
      }
      return map;
    } finally {
      client.close(force: true);
    }
  }

  /// Deteksi token expired dari response server.
  static bool _isTokenExpired(Map<String, dynamic> res) {
    if (res['code'] == 21007) return true;
    final msg = '${res['message'] ?? ''}'.toLowerCase();
    return msg.contains('inicie sesión') || msg.contains('login');
  }

  /// Cek sukses: code 10000 = OK.
  static bool isOk(Map<String, dynamic> res) {
    final code = res['code'];
    return code == 10000 || code == 0 || code == 200;
  }

  static List<dynamic> resultList(Map<String, dynamic> res) {
    final r = res['result'];
    if (r is List) return r;
    return const [];
  }

  // === Endpoint ===

  /// /api/search/screen -> feed besar (20 item) + filter audience/background/sort.
  /// Server anonim mengabaikan filter & paginasi, jadi ini sumber utama
  /// untuk memperbanyak konten per kategori.
  Future<List<Map<String, dynamic>>> screenRaw({
    int page = 1,
    int pageSize = 20,
    String? audience,
    String? background,
    String? sort,
  }) async {
    final body = <String, dynamic>{'pn': page, 'psize': pageSize};
    if (audience != null && audience.isNotEmpty) body['audience'] = audience;
    if (background != null && background.isNotEmpty) body['background'] = background;
    if (sort != null && sort.isNotEmpty) body['sort'] = sort;
    final res = await post(ShortDramaConfig.epSearchScreen, body);
    if (!isOk(res)) return const [];
    return resultList(res)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// /api/search/newbie_top -> 5 item.
  Future<List<Map<String, dynamic>>> newbieTopRaw() async {
    final res = await post(ShortDramaConfig.epSearchNewbieTop, {});
    if (!isOk(res)) return const [];
    return resultList(res)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// /api/channel/get_list -> daftar tab (id, channel_name, channel_type).
  Future<List<Map<String, dynamic>>> channelList() async {
    final res = await post(ShortDramaConfig.epChannelList, {});
    if (!isOk(res)) throw Exception('ShortDrama channel_list: ${res['message']}');
    return resultList(res).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// /api/channel/get_info -> feed konten satu channel (raw + mapped).
  Future<({List<ContentItem> items, List<Map<String, dynamic>> raw, bool hasMore})> channelInfo({
    required int channelId,
    int page = 1,
    int pageSize = 20,
    int vodType = 0,
    String category = '',
  }) async {
    final res = await post(ShortDramaConfig.epChannelInfo, {
      'channel_id': channelId,
      'pn': page,
      'psize': pageSize,
      'vod_type': vodType,
    });
    if (!isOk(res)) {
      return (items: <ContentItem>[], raw: <Map<String, dynamic>>[], hasMore: false);
    }
    final raw = resultList(res)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final items = raw
        .map((e) => _mapItem(e, category))
        .where((e) => e.id.isNotEmpty)
        .toList();
    return (items: items, raw: raw, hasMore: raw.length >= pageSize);
  }

  /// /api/vod_short/list_new -> short drama terbaru + play URL.
  Future<List<Map<String, dynamic>>> vodShortNewRaw() async {
    final res = await post(ShortDramaConfig.epVodShortNew, {});
    if (!isOk(res)) return const [];
    return resultList(res)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<ContentItem> mapAll(List<Map<String, dynamic>> raw, String category) => raw
      .map((e) => _mapItem(e, category))
      .where((e) => e.id.isNotEmpty)
      .toList();

  /// /api/search/result -> pencarian (raw).
  Future<List<Map<String, dynamic>>> searchRaw(String keyword, {int page = 1}) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return const [];
    final res = await post(ShortDramaConfig.epSearchResult, {'kw': clean, 'pn': '$page'});
    if (!isOk(res)) return const [];
    return resultList(res)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// /api/search/hot_search -> pencarian populer (raw).
  Future<List<Map<String, dynamic>>> hotSearchRaw() async {
    final res = await post(ShortDramaConfig.epSearchHot, {'vod_type': 0});
    if (!isOk(res)) return const [];
    return resultList(res)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// /api/type/get_list -> daftar genre/theme.
  Future<List<String>> typeList({int vodType = 0}) async {
    final res = await post(ShortDramaConfig.epTypeList, {'vod_type': vodType});
    if (!isOk(res)) return const [];
    final out = <String>[];
    for (final group in resultList(res)) {
      if (group is Map) {
        final data = group['data'];
        if (data is List) {
          for (final d in data) {
            final s = '$d'.trim();
            if (s.isNotEmpty && s.toLowerCase() != 'todo') out.add(s);
          }
        }
      }
    }
    return out;
  }

  /// Map item API -> ContentItem.
  ContentItem _mapItem(Map<String, dynamic> m, String category) {
    final id = '${m['id'] ?? m['vod_id'] ?? ''}';
    final title = '${m['vod_name'] ?? m['name'] ?? m['title'] ?? 'Tanpa judul'}';
    final cover = '${m['vod_pic'] ?? m['pic'] ?? m['cover'] ?? ''}';
    final total = int.tryParse('${m['vod_total'] ?? m['vod_serial'] ?? 0}') ?? 0;

    // Tag = theme + background (dipakai filter genre & sulih suara).
    final tags = <String>[];
    for (final key in ['theme', 'background']) {
      final raw = '${m[key] ?? ''}';
      for (final t in raw.split(',')) {
        final s = t.trim();
        if (s.isNotEmpty && !tags.contains(s)) tags.add(s);
      }
    }

    return ContentItem(
      id: id,
      title: title,
      source: 'ShortDrama',
      category: category,
      description: '${m['vod_blurb'] ?? m['content'] ?? ''}',
      posterUrl: cover,
      backdropUrl: cover,
      rating: 8.0,
      episodes: total <= 0 ? 1 : total,
      platformSlug: 'shortdrama',
      lang: 'id',
      tags: tags,
    );
  }
}
