import 'dart:convert';
import 'dart:io';

import '../../models/content_item.dart';
import 'cinemaid_config.dart';

/// HTTP client CinemaID — meniru request APK (native Kotlin, ExoPlayer).
///
/// - Semua API di bawah {base}/api/... ; base server-driven dari
///   GET /api/public/init -> data.sys_conf.api_url (fallback http://dg10.tv)
/// - Request GET dengan query param (gaya ?vod_id= terobservasi di biner)
/// - Auth: token dari /api/public/login|register, dikirim sebagai
///   Authorization header DAN query param `token` (lihat CinemaIdConfig)
class CinemaIdClient {
  String? _baseUrl;
  String? _token;
  bool _initTried = false;

  String? get token => _token;
  void setToken(String token) => _token = token;

  void _applyHeaders(HttpHeaders headers) {
    headers.set('User-Agent', CinemaIdConfig.userAgent);
    headers.set('Accept', 'application/json');
    headers.set('Content-Type', 'application/json; charset=UTF-8');
    if (CinemaIdConfig.sendTokenAsHeader && _token != null) {
      headers.set('Authorization', 'Bearer $_token');
    }
  }

  /// Pastikan base URL sudah di-resolve via /api/public/init.
  Future<String> _base() async {
    if (_baseUrl != null) return _baseUrl!;
    if (_initTried) return _normalizeUrl(CinemaIdConfig.fallbackBaseUrl);
    _initTried = true;

    var resolved = _normalizeUrl(CinemaIdConfig.fallbackBaseUrl);
    try {
      final uri = Uri.parse('$resolved/api${CinemaIdConfig.initPath}');
      final res = await _rawGet(uri);
      final sysConf = (res['data'] as Map?)?['sys_conf'] as Map?;
      final apiUrl = '${sysConf?['api_url'] ?? ''}'.trim();
      if (apiUrl.isNotEmpty) resolved = _normalizeUrl(apiUrl);
      final apiUrl2 = '${sysConf?['api_url2'] ?? ''}'.trim();
      if (resolved == _normalizeUrl(CinemaIdConfig.fallbackBaseUrl) && apiUrl2.isNotEmpty) {
        resolved = _normalizeUrl(apiUrl2);
      }
    } catch (_) {
      // init gagal -> pakai fallback hardcoded, tanpa retry
    }
    _baseUrl = resolved;
    return resolved;
  }

  String _normalizeUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  Future<Map<String, dynamic>> _rawGet(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(CinemaIdConfig.timeout);
      _applyHeaders(request.headers);
      final response = await request.close().timeout(CinemaIdConfig.timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('CinemaID ${response.statusCode} ${uri.path}: $body');
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

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final base = await _base();
    final params = Map<String, String>.from(query);
    if (CinemaIdConfig.sendTokenAsQuery && _token != null) {
      params[CinemaIdConfig.tokenQueryKey] = _token!;
    }
    final uri = Uri.parse('$base/api$path').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final res = await _rawGet(uri);
    final code = res['code'];
    // Wrapper tidak konsisten antar backend drama: 0/1/200 semua berarti
    // sukses di beberapa API. Hanya throw kalau data kosong DAN code
    // jelas bukan kode sukses — jangan gagalkan home gara-gara code.
    const okCodes = {0, 1, 200, '0', '1', '200'};
    final codeOk = code == null || okCodes.contains(code);
    if (!codeOk && res['data'] == null) {
      throw Exception('CinemaID code=$code msg=${res['msg'] ?? res['message']} path=$path');
    }
    return res;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final base = await _base();
    var uri = Uri.parse('$base/api$path');
    if (CinemaIdConfig.sendTokenAsQuery && _token != null) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        CinemaIdConfig.tokenQueryKey: _token!,
      });
    }
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(CinemaIdConfig.timeout);
      _applyHeaders(request.headers);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(CinemaIdConfig.timeout);
      final respBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('CinemaID ${response.statusCode} $path: $respBody');
      }
      if (respBody.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(respBody);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'success': true, 'data': decoded};
    } finally {
      client.close(force: true);
    }
  }

  ContentItem _toContentItem(Map m, String category) {
    final id = '${m['vod_id'] ?? m['id'] ?? ''}';
    return ContentItem(
      id: id,
      title: '${m['vod_name'] ?? m['title'] ?? m['name'] ?? 'No title'}',
      source: 'cinemaid',
      category: category,
      description: '${m['vod_desc'] ?? m['desc'] ?? m['description'] ?? ''}',
      posterUrl: '${m['vod_pic'] ?? m['pic'] ?? m['cover'] ?? m['poster'] ?? ''}',
      backdropUrl: '${m['vod_pic'] ?? m['pic'] ?? m['cover'] ?? ''}',
      rating: double.tryParse('${m['vod_score'] ?? m['rating'] ?? 0}') ?? 0,
      episodes: int.tryParse('${m['vod_episode'] ?? m['episode_count'] ?? 0}') ?? 0,
      platformSlug: 'cinemaid',
    );
  }

  List<Map> _asMaps(Object? raw) {
    if (raw is List) {
      return raw.whereType<Map>().toList();
    }
    return const [];
  }

  /// GET /api/topic/list -> block_list[] (module_id, module_name, type, videoList[]).
  /// Return modul mentah untuk dipakai homeByCategory.
  Future<List<Map<String, dynamic>>> topicModules() async {
    final res = await _getJson('/topic/list', const {});
    final data = res['data'];
    final list = data is Map
        ? _asMaps(data['block_list'] ??
            data['list'] ??
            data['items'] ??
            data['modules'] ??
            data['data'])
        : _asMaps(data);
    return list.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// GET /api/topic/change?module_id=.. -> refresh satu modul.
  Future<List<ContentItem>> refreshModule(String moduleId) async {
    final res = await _getJson('/topic/change', {'module_id': moduleId});
    final data = res['data'];
    final items = data is Map
        ? _asMaps(data['videoList'] ?? data['video_list'] ?? data['list'])
        : _asMaps(data);
    return items
        .map((m) => _toContentItem(m, 'refresh'))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// GET /api/topic/vod_list?topic_id=.. -> isi satu topik.
  Future<List<ContentItem>> topicVods(String topicId, {String category = ''}) async {
    final res = await _getJson('/topic/vod_list', {'topic_id': topicId});
    final data = res['data'];
    final items = data is Map ? _asMaps(data['list'] ?? data['items'] ?? data['videoList']) : _asMaps(data);
    return items
        .map((m) => _toContentItem(m, category))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// GET /api/type/get_list -> daftar tipe/kategori.
  Future<List<Map<String, dynamic>>> typeList() async {
    final res = await _getJson('/type/get_list', const {});
    final data = res['data'];
    final list = data is Map ? _asMaps(data['list'] ?? data['items'] ?? data['types']) : _asMaps(data);
    return list.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// GET /api/channel/get_list -> daftar channel/kategori.
  Future<List<Map<String, dynamic>>> channelList() async {
    final res = await _getJson('/channel/get_list', const {});
    final data = res['data'];
    final list = data is Map ? _asMaps(data['list'] ?? data['items'] ?? data['channels']) : _asMaps(data);
    return list.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// GET /api/channel/get_info?.. -> info channel.
  Future<Map<String, dynamic>> channelInfo(Map<String, String> query) async {
    final res = await _getJson('/channel/get_info', query);
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// GET /api/search/result?keyword=.. -> hasil pencarian.
  Future<List<ContentItem>> search(String keyword) async {
    final res = await _getJson('/search/result', {'keyword': keyword});
    final data = res['data'];
    final items = data is Map ? _asMaps(data['list'] ?? data['items'] ?? data['result']) : _asMaps(data);
    return items
        .map((m) => _toContentItem(m, 'search'))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// GET /api/vod/info_new?vod_id=..&collection=.. -> detail + episode.
  ///
  /// Return: { 'info': <Map detail>, 'episodes': <List<Map>> }.
  /// Tiap episode: vod_id, title, episodeNum, vod_url (stream langsung),
  /// down_url. Tidak perlu getplayinfo (mirip FreeReels).
  Future<Map<String, dynamic>> vodInfo(String vodId, {String collection = ''}) async {
    final res = await _getJson('/vod/info_new', {
      'vod_id': vodId,
      'collection': collection,
    });
    final data = res['data'] as Map? ?? {};
    final info = (data['vod'] ?? data['info'] ?? {}) as Map? ?? {};
    final episodes = _asMaps(data['vod_collection'] ??
            data['episode_list'] ??
            data['episodes'] ??
            data['list'])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return {
      'info': Map<String, dynamic>.from(info),
      'episodes': episodes,
    };
  }

  /// POST /api/public/login {username, password} -> token.
  Future<String> login(String username, String password) async {
    final res = await _postJson('/public/login', {
      'username': username,
      'password': password,
    });
    final data = res['data'] as Map? ?? {};
    final token = '${data['token'] ?? ''}';
    if (token.isEmpty) throw Exception('CinemaID login: token kosong');
    _token = token;
    return token;
  }

  /// POST /api/public/register {...} -> token.
  Future<String> register(Map<String, dynamic> fields) async {
    final res = await _postJson('/public/register', fields);
    final data = res['data'] as Map? ?? {};
    final token = '${data['token'] ?? ''}';
    if (token.isEmpty) throw Exception('CinemaID register: token kosong');
    _token = token;
    return token;
  }
}
