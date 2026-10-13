import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../../models/content_item.dart';
import 'cinemaid_config.dart';
import 'cinemaid_crypto.dart';
import 'cinemaid_session.dart';

class CinemaIdClient {
  String? _baseUrl;
  String? _token = CinemaIdConfig.defaultToken;
  bool _initTried = false;
  String _deviceId = CinemaIdConfig.defaultDeviceId;
  bool _autoLoginTried = false;

  String? get token => _token;
  String get deviceId => _deviceId;
  void setToken(String token) => _token = token;
  void setDeviceId(String id) => _deviceId = id;

  Future<void> ensureSession() async {
    if (_token != null && _token!.isNotEmpty && _deviceId.isNotEmpty) return;
    try {
      final session = await CinemaIdSession.read();
      final sessToken = session['token'];
      final sessDevId = session['deviceId'];
      if (sessToken != null && sessToken.isNotEmpty) _token = sessToken;
      if (sessDevId != null && sessDevId.isNotEmpty) _deviceId = sessDevId;
    } catch (_) {}
    if (_deviceId.isEmpty) {
      _deviceId = CinemaIdConfig.defaultDeviceId;
    }
    if (_token == null || _token!.isEmpty) {
      _token = CinemaIdConfig.defaultToken;
    }
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

  Future<Map<String, dynamic>> _ensureBaseAndAuth() async {
    await ensureSession();
    final base = await _base();
    return {'base': base};
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
    const okCodes = {0, 1, 200, 10000, '0', '1', '200', '10000'};
    final codeOk = code == null || okCodes.contains(code);
    if (!codeOk && res['data'] == null && res['result'] == null) {
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
