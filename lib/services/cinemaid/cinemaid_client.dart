import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../../models/content_item.dart';
import 'cinemaid_config.dart';
import 'cinemaid_crypto.dart';
import 'cinemaid_session.dart';

/// Error auth CinemaID: token/sesi ditolak server (HTTP 401/403 atau
/// kode auth). Ditangani khusus — client mencoba pulih (identitas tamu
/// baru) sekali sebelum gagal ke pemanggil.
class CinemaIdAuthException implements Exception {
  final String message;
  const CinemaIdAuthException(this.message);
  @override
  String toString() => 'CinemaIdAuthException: $message';
}

/// Kode respons server yang menandakan sesi/token tidak valid.
bool isCinemaIdAuthCode(Object? code) {
  const authCodes = {
    4001, 401, 403, 1001, 1002, 1003, 10001, 40001, 40003,
    '4001', '401', '403', '1001', '1002', '1003', '10001', '40001', '40003',
  };
  return authCodes.contains(code);
}

/// Pesan error yang menandakan sesi/token tidak valid.
bool cinemaIdMessageLooksLikeAuth(String message) {
  final m = message.toLowerCase();
  return m.contains('401') ||
      m.contains('403') ||
      m.contains('4001') ||
      m.contains('user_not_login') ||
      m.contains('not login') ||
      m.contains('token') ||
      m.contains('unauthorized') ||
      m.contains('session') ||
      m.contains('auth');
}

class CinemaIdClient {
  String? _baseUrl;

  /// Token mulai null (bukan default hardcoded) supaya ensureSession()
  /// benar-benar jalan: sesi tersimpan -> auto-register -> default.
  /// Default hardcoded hanya cadangan terakhir kalau dua jalur di atas gagal.
  String? _token;
  String _deviceId = '';

  /// Pengaman re-entrancy: ensureSession() -> _autoRegister() memanggil
  /// _rawPost yang tidak boleh memicu ensureSession lagi.
  bool _sessionResolving = false;

  String? get token => _token;
  String get deviceId => _deviceId;
  void setToken(String token) => _token = token;
  void setDeviceId(String id) => _deviceId = id;

  /// Sesi dinamis-first:
  /// 1. Token tersimpan (hasil login/register/auto-register sebelumnya).
  /// 2. Auto-register identitas tamu baru (device_id unik per install).
  /// 3. Token + device_id hardcoded sebagai cadangan terakhir.
  Future<void> ensureSession() async {
    if (_token != null && _token!.isNotEmpty && _deviceId.isNotEmpty) return;
    if (_sessionResolving) return;
    _sessionResolving = true;
    try {
      try {
        final session = await CinemaIdSession.read();
        final sessToken = session['token'];
        final sessDevId = session['deviceId'];
        if (sessToken != null && sessToken.isNotEmpty) _token = sessToken;
        if (sessDevId != null && sessDevId.isNotEmpty) _deviceId = sessDevId;
      } catch (_) {}
      if (_token != null && _token!.isNotEmpty && _deviceId.isNotEmpty) return;
      try {
        if (await _autoRegister()) return;
      } catch (_) {}
      if (_deviceId.isEmpty) {
        _deviceId = CinemaIdConfig.defaultDeviceId;
      }
      if (_token == null || _token!.isEmpty) {
        _token = CinemaIdConfig.defaultToken;
      }
    } finally {
      _sessionResolving = false;
    }
  }

  /// Daftar identitas tamu baru ke server. Pakai _rawPost langsung (bukan
  /// _postJson) supaya tidak re-enter ensureSession. Gagal -> false,
  /// pemanggil jatuh ke token hardcoded.
  Future<bool> _autoRegister() async {
    final deviceId = _randomDeviceId();
    final username = '${CinemaIdConfig.autoRegisterUsername}_$deviceId';
    _deviceId = deviceId;
    _token = null;
    final uri = Uri.parse(
      '${_normalizeUrl(CinemaIdConfig.baseUrl)}/api/public/register',
    );
    final res = await _rawPost(uri, {
      'username': username,
      'password': CinemaIdConfig.autoRegisterPassword,
      'device_id': deviceId,
    });
    final token = _extractToken(res);
    if (token.isEmpty) return false;
    _token = token;
    try {
      await CinemaIdSession.save(
        token: token,
        userId: _extractUserId(res),
        deviceId: deviceId,
        isSvip: '0',
      );
    } catch (_) {}
    return true;
  }

  String _extractToken(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map && '${data['token'] ?? ''}'.isNotEmpty) {
      return '${data['token']}';
    }
    final result = res['result'];
    if (result is Map && '${result['token'] ?? ''}'.isNotEmpty) {
      return '${result['token']}';
    }
    if ('${res['token'] ?? ''}'.isNotEmpty) return '${res['token']}';
    return '';
  }

  String _extractUserId(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map) return '${data['user_id'] ?? data['userId'] ?? data['id'] ?? ''}';
    return '';
  }

  String _randomDeviceId() {
    final rnd = Random.secure();
    const hex = '0123456789abcdef';
    return List.generate(16, (_) => hex[rnd.nextInt(16)]).join();
  }

  /// Pulih dari error auth: buang sesi lama, bangun sesi baru
  /// (tersimpan -> auto-register -> default), lalu pemanggil retry sekali.
  Future<void> _recoverAuth() async {
    try {
      await CinemaIdSession.clear();
    } catch (_) {}
    _token = null;
    _deviceId = '';
    await ensureSession();
  }

  /// Keluar: buang sesi tersimpan + sesi runtime. Request berikutnya
  /// membangun identitas baru (auto-register) — bukan kembali ke token
  /// lama. Tidak menghapus fallback hardcoded di config (cadangan terakhir).
  Future<void> signOut() async {
    try {
      await CinemaIdSession.clear();
    } catch (_) {}
    _token = null;
    _deviceId = '';
  }

  void _applyHeaders(HttpHeaders headers) {
    final effectiveDeviceId = _deviceId.isNotEmpty ? _deviceId : CinemaIdConfig.defaultDeviceId;
    final curTime = DateTime.now().millisecondsSinceEpoch.toString();
    final effectiveToken = (_token != null && _token!.isNotEmpty) ? _token! : CinemaIdConfig.defaultToken;
    final signed = CinemaIdCrypto.buildHeaders(
      deviceId: effectiveDeviceId,
      curTime: curTime,
      token: effectiveToken,
    );
    signed.forEach((k, v) {
      headers.set(k, v);
    });
  }

  /// Pastikan base URL siap langsung tanpa memblokir request.
  Future<String> _base() async {
    await ensureSession();
    if (_baseUrl != null && _baseUrl!.isNotEmpty) return _baseUrl!;
    _baseUrl = _normalizeUrl(CinemaIdConfig.baseUrl);
    return _baseUrl!;
  }

  String _normalizeUrl(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<Map<String, dynamic>> _rawPost(Uri uri, Map<String, dynamic> form) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    try {
      final request = await client.postUrl(uri).timeout(CinemaIdConfig.timeout);
      _applyHeaders(request.headers);
      final encodedBody = form.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}')
          .join('&');
      request.write(encodedBody);
      final response = await request.close().timeout(CinemaIdConfig.timeout);
      final rawBody = await response.transform(utf8.decoder).join();
      debugPrint('CINEMAID CLIENT: status=${response.statusCode} path=${uri.path} bodyLen=${rawBody.length}');
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw CinemaIdAuthException(
          'CinemaID ${response.statusCode} ${uri.path}: sesi ditolak server',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('CinemaID ${response.statusCode} ${uri.path}: $rawBody');
      }
      if (rawBody.trim().isEmpty) return <String, dynamic>{};
      
      final decrypted = CinemaIdCrypto.decryptResponse(rawBody);
      debugPrint('CINEMAID CLIENT: decrypted type=${decrypted.runtimeType} isMap=${decrypted is Map}');
      if (decrypted is Map<String, dynamic>) return decrypted;
      if (decrypted is Map) return Map<String, dynamic>.from(decrypted);
      return <String, dynamic>{'success': true, 'data': decrypted};
    } finally {
      client.close(force: true);
    }
  }

  /// GET + pemulihan auth: kalau server menolak sesi, bangun sesi baru
  /// (auto-register) dan coba sekali lagi. Gagal kedua -> error ke pemanggil.
  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query, {
    bool authRetried = false,
  }) async {
    try {
      return await _getJsonOnce(path, query);
    } on CinemaIdAuthException {
      if (authRetried) rethrow;
      await _recoverAuth();
      return _getJson(path, query, authRetried: true);
    }
  }

  Future<Map<String, dynamic>> _getJsonOnce(
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
    const okCodes = {0, 1, 200, 10000, '0', '1', '200', '10000'};
    final codeOk = code == null || okCodes.contains(code);
    if (!codeOk && res['data'] == null && res['result'] == null) {
      final msg = '${res['msg'] ?? res['message'] ?? ''}';
      if (isCinemaIdAuthCode(code) || cinemaIdMessageLooksLikeAuth(msg)) {
        throw CinemaIdAuthException('CinemaID code=$code msg=$msg path=$path');
      }
      throw Exception('CinemaID code=$code msg=$msg path=$path');
    }
    return res;
  }

  /// POST + pemulihan auth (sama seperti [_getJson]).
  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    bool authRetried = false,
  }) async {
    try {
      return await _postJsonOnce(path, body);
    } on CinemaIdAuthException {
      if (authRetried) rethrow;
      await _recoverAuth();
      return _postJson(path, body, authRetried: true);
    }
  }

  Future<Map<String, dynamic>> _postJsonOnce(
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
      rating: double.tryParse('${m['vod_score'] ?? m['vod_douban_score'] ?? m['rating'] ?? 0}') ?? 0,
      episodes: int.tryParse('${m['vod_episode'] ?? m['vod_total'] ?? m['episode_count'] ?? 0}') ?? 0,
      platformSlug: 'cinemaid',
    );
  }

  List<Map> _asMaps(Object? raw) {
    if (raw is List) {
      return raw.whereType<Map>().toList();
    }
    return const [];
  }

  /// POST /api/channel/get_info?channel_id=202 -> blok modul live (Trending, Streaming, dll).
  Future<List<Map<String, dynamic>>> channelModules({String channelId = '202'}) async {
    final res = await _postJson('/channel/get_info', {'channel_id': channelId});
    final rawList = (res['result'] ?? res['data']) as List? ?? [];
    return rawList.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// GET /api/topic/list -> block_list[] (module_id, module_name, type, videoList[]).
  /// Return modul mentah untuk dipakai homeByCategory.
  Future<List<Map<String, dynamic>>> topicModules() async {
    try {
      final chModules = await channelModules(channelId: '202');
      if (chModules.isNotEmpty) return chModules;
    } catch (_) {}

    final res = await _getJson('/topic/list', const {});
    final data = res['result'] ?? res['data'];
    final list = data is Map
        ? _asMaps(data['block_list'] ??
            data['topic_list'] ??
            data['list'] ??
            data['items'] ??
            data['modules'] ??
            data['data'])
        : _asMaps(data);
    return list.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// Cari topic_id server berdasarkan nama platform (case-insensitive).
  /// Dipakai untuk platform tanpa topic_id hardcoded (Vidio, Vivamax, Viu, iFlix).
  /// Return '' jika tidak ketemu.
  Future<String> discoverTopicId(String platformName) async {
    try {
      final modules = await topicModules();
      final norm = platformName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final m in modules) {
        final name = '${m['topic_name'] ?? m['module_name'] ?? m['name'] ?? m['title'] ?? ''}';
        final nameNorm = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (nameNorm.isEmpty) continue;
        if (nameNorm == norm || nameNorm.contains(norm) || norm.contains(nameNorm)) {
          final id = '${m['topic_id'] ?? m['module_id'] ?? m['id'] ?? ''}';
          if (id.isNotEmpty) {
            return id;
          }
        }
      }
      // Coba juga gali videoList di dalam modul untuk nama topic tersembunyi
      for (final m in modules) {
        final videoList = m['videoList'] ?? m['video_list'] ?? m['list'];
        if (videoList is List) {
          for (final v in videoList.whereType<Map>()) {
            final name = '${v['topic_name'] ?? v['name'] ?? v['title'] ?? ''}';
            final nameNorm = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            if (nameNorm.isEmpty) continue;
            if (nameNorm == norm || nameNorm.contains(norm) || norm.contains(nameNorm)) {
              final id = '${v['topic_id'] ?? v['id'] ?? ''}';
              if (id.isNotEmpty) return id;
            }
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// GET /api/topic/change?module_id=.. -> refresh satu modul.
  Future<List<ContentItem>> refreshModule(String moduleId) async {
    final res = await _getJson('/topic/change', {'module_id': moduleId});
    final data = res['result'] ?? res['data'];
    final items = data is Map
        ? _asMaps(data['vod_list'] ?? data['videoList'] ?? data['video_list'] ?? data['list'])
        : _asMaps(data);
    return items
        .map((m) => _toContentItem(m, 'refresh'))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// GET /api/topic/vod_list?topic_id=.. -> isi satu topik.
  /// Dukung paginasi via [page] (0-based).
  Future<List<ContentItem>> topicVods(String topicId,
      {String category = '', int page = 0}) async {
    final params = <String, String>{'topic_id': topicId};
    if (page > 0) params['page'] = '$page';
    final res = await _getJson('/topic/vod_list', params);
    final data = res['result'] ?? res['data'];
    final items = data is Map
        ? _asMaps(data['vod_list'] ?? data['list'] ?? data['items'] ?? data['videoList'])
        : _asMaps(data);
    return items
        .map((m) => _toContentItem(m, category))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// Ambil semua halaman vod_list satu topik (ala FreeReels: paginasi penuh
  /// agar konten per tab maksimal dan tidak itu-itu saja).
  Future<List<ContentItem>> allVodsFromTopic(String topicId,
      {String category = '', int maxPages = 10}) async {
    final seen = <String>{};
    final all = <ContentItem>[];
    for (var page = 0; page < maxPages; page++) {
      List<ContentItem> batch;
      try {
        batch = await topicVods(topicId, category: category, page: page).timeout(
          const Duration(seconds: 15),
          onTimeout: () => const <ContentItem>[],
        );
      } catch (_) {
        break;
      }
      if (batch.isEmpty) break;
      var added = 0;
      for (final item in batch) {
        if (seen.add(item.id)) {
          all.add(item);
          added++;
        }
      }
      if (added == 0) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return all;
  }

  /// GET /api/type/get_list -> daftar tipe/kategori.
  Future<List<Map<String, dynamic>>> typeList() async {
    final res = await _getJson('/type/get_list', const {});
    final data = res['result'] ?? res['data'];
    final list = data is Map ? _asMaps(data['list'] ?? data['items'] ?? data['types']) : _asMaps(data);
    return list.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// GET /api/channel/get_list -> daftar channel/kategori.
  Future<List<Map<String, dynamic>>> channelList() async {
    final res = await _getJson('/channel/get_list', const {});
    final data = res['result'] ?? res['data'];
    final list = data is Map ? _asMaps(data['list'] ?? data['items'] ?? data['channels']) : _asMaps(data);
    return list.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// GET /api/channel/get_info?.. -> info channel.
  Future<Map<String, dynamic>> channelInfo(Map<String, String> query) async {
    final res = await _getJson('/channel/get_info', query);
    final data = res['result'] ?? res['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// GET /api/search/result?keyword=.. -> hasil pencarian.
  Future<List<ContentItem>> search(String keyword) async {
    final res = await _getJson('/search/result', {'keyword': keyword});
    final data = res['result'] ?? res['data'];
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
    final data = (res['result'] ?? res['data']) as Map? ?? {};
    final info = (data['vod'] ?? data['info'] ?? data) as Map? ?? {};
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
  /// Token disimpan ke sesi supaya tidak hilang saat restart.
  Future<String> login(String username, String password) async {
    final res = await _postJson('/public/login', {
      'username': username,
      'password': password,
    }, authRetried: true);
    final token = _extractToken(res);
    if (token.isEmpty) throw Exception('CinemaID login: token kosong');
    _token = token;
    try {
      await CinemaIdSession.save(
        token: token,
        userId: _extractUserId(res),
        deviceId: _deviceId,
        isSvip: '0',
      );
    } catch (_) {}
    return token;
  }

  /// POST /api/public/register {...} -> token.
  /// Token disimpan ke sesi supaya tidak hilang saat restart.
  Future<String> register(Map<String, dynamic> fields) async {
    final res = await _postJson('/public/register', fields, authRetried: true);
    final token = _extractToken(res);
    if (token.isEmpty) throw Exception('CinemaID register: token kosong');
    _token = token;
    try {
      await CinemaIdSession.save(
        token: token,
        userId: _extractUserId(res),
        deviceId: _deviceId,
        isSvip: '0',
      );
    } catch (_) {}
    return token;
  }
}
