import 'dart:convert';
import 'dart:io';

import '../../models/content_item.dart';
import 'cinemaid_config.dart';
import 'cinemaid_crypto.dart';

class CinemaIdClient {
  String? _baseUrl;
  String? _token;
  bool _initTried = false;
  final String _deviceId = 'd79148d1c6bebfd5';

  String? get token => _token;
  void setToken(String token) => _token = token;

  void _applyHeaders(HttpHeaders headers) {
    final curTime = DateTime.now().millisecondsSinceEpoch.toString();
    final signed = CinemaIdCrypto.buildHeaders(
      deviceId: _deviceId,
      curTime: curTime,
      token: _token ?? '',
    );
    signed.forEach((k, v) {
      headers.set(k, v);
    });
  }

  /// Pastikan base URL sudah di-resolve via /api/public/init dan handshake portal lokal port 60000.
  Future<String> _base() async {
    // 1. Coba handshake dengan portal lokal libvindictus di 127.0.0.1:60000 jika aplikasi CinemaID aktif
    try {
      final localClient = HttpClient();
      final localReq = await localClient
          .getUrl(Uri.parse('http://127.0.0.1:60000/control?msg=verify&device_id=$_deviceId'))
          .timeout(const Duration(milliseconds: 500));
      final localResp = await localReq.close().timeout(const Duration(milliseconds: 500));
      if (localResp.statusCode == 200) {
        // Portal lokal aktif
      }
      localClient.close(force: true);
    } catch (_) {}

    if (_baseUrl != null) return _baseUrl!;
    if (_initTried) return _normalizeUrl(CinemaIdConfig.fallbackBaseUrl);
    _initTried = true;

    var resolved = _normalizeUrl(CinemaIdConfig.fallbackBaseUrl);
    try {
      final uri = Uri.parse('$resolved/api${CinemaIdConfig.initPath}');
      final res = await _rawPost(uri, {});
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

  Future<Map<String, dynamic>> _rawPost(Uri uri, Map<String, dynamic> form) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(CinemaIdConfig.timeout);
      _applyHeaders(request.headers);
      final encodedBody = form.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}')
          .join('&');
      request.write(encodedBody);
      final response = await request.close().timeout(CinemaIdConfig.timeout);
      final rawBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('CinemaID ${response.statusCode} ${uri.path}: $rawBody');
      }
      if (rawBody.trim().isEmpty) return <String, dynamic>{};
      
      final decrypted = CinemaIdCrypto.decryptResponse(rawBody);
      if (decrypted is Map<String, dynamic>) return decrypted;
      if (decrypted is Map) return Map<String, dynamic>.from(decrypted);
      return <String, dynamic>{'success': true, 'data': decrypted};
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final base = await _base();
    final uri = Uri.parse('$base/api$path');
    final params = Map<String, dynamic>.from(query);
    if (_token != null && _token!.isNotEmpty) {
      params['token'] = _token!;
    }
    final res = await _rawPost(uri, params);
    final code = res['code'];
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
    final uri = Uri.parse('$base/api$path');
    final params = Map<String, dynamic>.from(body);
    if (_token != null && _token!.isNotEmpty) {
      params['token'] = _token!;
    }
    return _rawPost(uri, params);
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
