import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'netshort_config.dart';
import 'netshort_crypto.dart';

/// Network Client untuk NetShort dengan enkripsi AES-256 + RSA-2048 otomatis,
/// session login visitor, dan caching metadata theater/token.
class NetShortClient {
  static NetShortClient? _instance;
  static NetShortClient get instance => _instance ??= NetShortClient._();

  NetShortClient._();

  String _token = '';
  String _deviceCode = '';
  String _theaterId = '';
  String _jsonParam = '';
  List<Map<String, dynamic>> _channels = [];

  bool get hasSession => _token.isNotEmpty;

  void signOut() {
    _token = '';
    _deviceCode = '';
    _theaterId = '';
    _jsonParam = '';
    _channels = [];
  }

  /// Generate deviceCode 16-hex jika belum ada
  String _getDeviceCode() {
    if (_deviceCode.isNotEmpty) return _deviceCode;
    final rnd = Random();
    final bytes = List<int>.generate(8, (_) => rnd.nextInt(256));
    _deviceCode = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _deviceCode;
  }

  /// Pastikan token aktif via /auth/login (visitor)
  Future<String> ensureToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _token.isNotEmpty) {
      return _token;
    }

    final devCode = _getDeviceCode();
    final payload = {
      'deviceCode': devCode,
      'deviceId': null,
      'model': NetShortConfig.defaultModel,
      'os': 'Android',
      'osVer': NetShortConfig.defaultOsVer,
      'appVer': NetShortConfig.appVersion,
      'source': 'visitor',
    };

    final resp = await _rawPost(NetShortConfig.authLogin, payload, requiresAuth: false);
    if (resp['code'] == 200 && resp['data'] != null) {
      final data = resp['data'] as Map<String, dynamic>;
      _token = data['token']?.toString() ?? '';
      return _token;
    }
    throw StateError('NetShort visitor login gagal: ${resp['msg']}');
  }

  /// Ambil info Home Theater & channels
  Future<Map<String, dynamic>> getTheaterHomeInfo() async {
    final token = await ensureToken();
    final resp = await _rawPost(NetShortConfig.theaterHomeInfo, {}, token: token);
    if (resp['code'] == 200 && resp['data'] != null) {
      final data = resp['data'] as Map<String, dynamic>;
      _theaterId = data['id']?.toString() ?? '';
      _jsonParam = data['jsonParam']?.toString() ?? '';
      final channelList = data['channelList'] as List<dynamic>? ?? [];
      if (channelList.isNotEmpty) {
        final children = (channelList[0] as Map<String, dynamic>)['childrenList'] as List<dynamic>? ?? [];
        _channels = children.cast<Map<String, dynamic>>();
      }
      return data;
    }
    return {};
  }

  /// Ambil video per channel/kategori
  Future<List<Map<String, dynamic>>> getChannelVideos(dynamic channelId) async {
    final token = await ensureToken();
    if (_theaterId.isEmpty || _jsonParam.isEmpty) {
      await getTheaterHomeInfo();
    }

    final payload = {
      'theaterId': int.tryParse(_theaterId) ?? 51,
      'channelId': channelId is int ? channelId : int.tryParse(channelId.toString()) ?? 345,
      'jsonParam': _jsonParam,
      'newUser': false,
    };

    final resp = await _rawPost(NetShortConfig.theaterChannelVideo, payload, token: token);
    if (resp['code'] == 200 && resp['data'] != null) {
      final data = resp['data'] as Map<String, dynamic>;
      final columnList = data['columnList'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> dramas = [];
      for (final col in columnList) {
        final modelList = (col as Map<String, dynamic>)['modelList'] as List<dynamic>? ?? [];
        for (final model in modelList) {
          final m = model as Map<String, dynamic>;
          final insertRespList = m['insertRespList'] as List<dynamic>? ?? [];
          for (final ins in insertRespList) {
            final sp = (ins as Map<String, dynamic>)['shortPlayResp'] as Map<String, dynamic>?;
            if (sp != null) {
              dramas.add(sp);
            }
          }
          final shortPlayRespList = m['shortPlayRespList'] as List<dynamic>? ?? [];
          for (final sp in shortPlayRespList) {
            if (sp is Map<String, dynamic>) {
              dramas.add(sp);
            }
          }
        }
      }
      return dramas;
    }
    return [];
  }

  /// Ambil Ranking Chart drama (Trending, Top Search, New Release)
  Future<List<Map<String, dynamic>>> getRankingCharts() async {
    final token = await ensureToken();
    final payload = {
      'language': NetShortConfig.defaultLanguage,
      'limit': 20,
    };

    final resp = await _rawPost(NetShortConfig.tabLoadAllChart, payload, token: token);
    if (resp['code'] == 200 && resp['data'] != null) {
      final data = resp['data'] as Map<String, dynamic>;
      final List<Map<String, dynamic>> items = [];
      for (final key in ['mostTrending', 'topSearch', 'newRelease']) {
        final val = data[key];
        if (val is Map<String, dynamic>) {
          final list = (val['shortPlayList'] ?? val['list']) as List<dynamic>? ?? [];
          items.addAll(list.cast<Map<String, dynamic>>());
        } else if (val is List<dynamic>) {
          items.addAll(val.cast<Map<String, dynamic>>());
        }
      }
      return items;
    }
    return [];
  }

  /// Ambil metadata detail drama + daftar episode (/video/shortPlay/base/detail_info/V2)
  Future<Map<String, dynamic>> getDetailInfoV2(String shortPlayId) async {
    final token = await ensureToken();
    final payload = {'shortPlayId': shortPlayId};
    final resp = await _rawPost(NetShortConfig.detailInfoV2, payload, token: token);
    if (resp['code'] == 200 && resp['data'] != null) {
      return resp['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// Ambil video stream voucher & subtitle untuk batch episode (/video/shortPlay/base/episode/detail_info)
  Future<List<Map<String, dynamic>>> getEpisodeDetailInfo({
    required String shortPlayId,
    required List<String> episodeIds,
  }) async {
    final token = await ensureToken();
    final payload = {
      'shortPlayId': shortPlayId,
      'episodeIds': episodeIds,
    };
    final resp = await _rawPost(NetShortConfig.episodeDetailInfo, payload, token: token);
    if (resp['code'] == 200 && resp['data'] != null) {
      final data = resp['data'];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      } else if (data is Map<String, dynamic>) {
        final list = data['shortPlayEpisodeInfos'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// Cari drama secara realtime (/video/shortPlay/search/realtime)
  Future<List<Map<String, dynamic>>> searchRealtime(String keyword) async {
    final token = await ensureToken();
    final payload = {
      'pageNo': 1,
      'pageSize': 20,
      'searchFlag': 0,
      'searchCode': keyword,
    };
    final resp = await _rawPost(NetShortConfig.searchRealtime, payload, token: token);
    if (resp['code'] == 200 && resp['data'] != null) {
      final data = resp['data'] as Map<String, dynamic>;
      final List<Map<String, dynamic>> results = [];
      for (final key in ['searchCodeSearchResult', 'slotSearchResult', 'simpleSearchResult']) {
        final list = data[key] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          results.addAll(list.cast<Map<String, dynamic>>());
        }
      }
      return results;
    }
    return [];
  }

  /// Eksekusi POST request terenkripsi AES + RSA dan dekripsi balasan
  Future<Map<String, dynamic>> _rawPost(
    String endpoint,
    Map<String, dynamic> bodyJson, {
    String? token,
    bool requiresAuth = true,
  }) async {
    // Retry pada kegagalan jaringan/DNS: koneksi seluler sering gagal resolve
    // sekali lalu berhasil pada percobaan berikutnya.
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _rawPostOnce(
          endpoint,
          bodyJson,
          token: token,
          requiresAuth: requiresAuth,
        );
      } catch (e) {
        lastError = e;
        debugPrint('NETSHORT NETWORK ERROR on $endpoint (attempt $attempt/3): $e');
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }
    debugPrint('NETSHORT GAVE UP on $endpoint: $lastError');
    return {'code': -1, 'msg': 'network error: $lastError', 'data': null};
  }

  Future<Map<String, dynamic>> _rawPostOnce(
    String endpoint,
    Map<String, dynamic> bodyJson, {
    String? token,
    bool requiresAuth = true,
  }) async {
    final devCode = _getDeviceCode();
    final aesKey = NetShortCrypto.generateAesKey();
    final encKeyHeader = NetShortCrypto.rsaEncrypt(Uint8List.fromList(utf8.encode(base64.encode(utf8.encode(aesKey)))));
    final jsonStr = jsonEncode(bodyJson);
    final ctBody = NetShortCrypto.aes256EcbEncrypt(jsonStr, aesKey);

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.badCertificateCallback = (cert, host, port) => true;

    try {
      final uri = Uri.parse('${NetShortConfig.baseUrl}$endpoint');
      final request = await client.postUrl(uri);

      request.headers.set('User-Agent', 'okhttp/4.9.0');
      request.headers.set('Accept', 'application/json, text/plain, */*');
      request.headers.set('encrypt-key', encKeyHeader);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('timestamp', DateTime.now().millisecondsSinceEpoch.toString());
      request.headers.set('content-language', NetShortConfig.defaultLanguage);
      request.headers.set('package-name', NetShortConfig.packageName);
      request.headers.set('version', NetShortConfig.appVersion);
      request.headers.set('version-name', NetShortConfig.appVersion);
      request.headers.set('version-code', NetShortConfig.versionCode);
      request.headers.set('os', NetShortConfig.os);
      request.headers.set('canary', NetShortConfig.canary);
      request.headers.set('Device-Code', devCode);

      if (token != null && token.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $token');
      }

      request.write(ctBody);
      final response = await request.close();

      final resEncKey = response.headers.value('encrypt-key');
      final resBytes = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      final resText = utf8.decode(resBytes, allowMalformed: true).trim();

      if (resEncKey != null && resEncKey.isNotEmpty) {
        try {
          final decAesKeyBytes = await NetShortCrypto.nativeRsaDecrypt(base64.decode(resEncKey.trim()));
          final rawKeyStr = utf8.decode(decAesKeyBytes).trim();
          final rawKeyBytes = base64.decode(rawKeyStr);
          final plainJson = await NetShortCrypto.nativeAesDecrypt(resText, rawKeyBytes);
          return jsonDecode(plainJson) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('NETSHORT DECRYPT ERROR on $endpoint: $e');
        }
      }

      if (resText.isNotEmpty) {
        try {
          return jsonDecode(resText) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('NETSHORT JSON ERROR on $endpoint (status ${response.statusCode}): $resText');
        }
      }

      return {'code': response.statusCode, 'msg': 'HTTP ${response.statusCode}', 'data': null};
    } finally {
      client.close(force: true);
    }
  }

  List<Map<String, dynamic>> get cachedChannels => _channels;
  String get cachedTheaterId => _theaterId;
  String get cachedJsonParam => _jsonParam;
}
