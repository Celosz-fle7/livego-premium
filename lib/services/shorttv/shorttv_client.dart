import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'shorttv_config.dart';
import 'shorttv_crypto.dart';
import 'shorttv_stream_proxy.dart';

/// HTTP Client Mandiri untuk ShortTV API (https://api.shorttv.live).
/// Mendukung login otomatis (initLogin), discovery ranking per kategori bahasa,
/// detail drama, daftar episode, dan link streaming multi-resolusi HLS.
class ShortTvClient {
  static ShortTvClient? _instance;
  static ShortTvClient get instance => _instance ??= ShortTvClient._();

  ShortTvClient._();

  String _token = ShortTvConfig.defaultToken;
  DateTime? _tokenExpiry;

  /// Generate UUID v4 sederhana
  String _randomUuid() {
    final rnd = Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hexChars = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hexChars.substring(0, 8)}-${hexChars.substring(8, 12)}-${hexChars.substring(12, 16)}-${hexChars.substring(16, 20)}-${hexChars.substring(20, 32)}';
  }

  /// Pastikan token aktif. Jika belum ada atau mendekati expired (> 24 jam), panggil initLogin.
  Future<String> _ensureToken() async {
    if (_token.isNotEmpty && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _token;
    }

    try {
      final seq = _randomUuid();
      final deviceId = ShortTvConfig.defaultDeviceId;
      final secretKey = ShortTvConfig.defaultRc4RsaKey;

      final bodyMap = {
        'deviceCode': deviceId,
        'seq': seq,
        'secretKey': secretKey,
      };
      final bodyStr = jsonEncode(bodyMap);

      // Hitung traceParam: RC4(MD5(deviceId + seq + secretKey + "34"))
      final concat = '$deviceId$seq${secretKey}34';
      final md5Hash = md5.convert(utf8.encode(concat)).toString();
      final traceParam = ShortTvCrypto.rc4EncryptHex(md5Hash, ShortTvConfig.defaultRc4Key);

      final headers = {
        'isEncrypt': 'false',
        'channel': 'googleplay',
        'deviceId': deviceId,
        'clientPlatform': 'android',
        'TraceId': _randomUuid(),
        'TraceParam': traceParam,
        'language': 'id',
        'locale': 'id_ID',
        'timeZone': 'Asia/Jakarta',
        'model': '2201116PG',
        'systemVersion': '14',
        'androidVersion': '34',
        'mcc': '510',
        'environment': 'prod',
        'buildValue': '328',
        'afVersion': '1',
        'hasProxy': 'false',
        'resolution': '1080x2400',
        'system_country_code': 'ID',
        'isR': 'false',
        'isE': 'false',
        'isD': 'false',
        'vefCode': ShortTvCrypto.calculateVefCode(deviceId),
        'Content-Type': 'application/json;charset=utf-8',
        'User-Agent': 'okhttp/4.11.0',
      };

      final client = HttpClient();
      try {
        final uri = Uri.parse('${ShortTvConfig.baseUrl}/app/login/v4/initLogin');
        final req = await client.postUrl(uri).timeout(ShortTvConfig.timeout);
        headers.forEach((k, v) => req.headers.set(k, v));
        req.write(bodyStr);
        final resp = await req.close().timeout(ShortTvConfig.timeout);
        final respBody = await resp.transform(utf8.decoder).join();

        if (resp.statusCode == 200 && respBody.isNotEmpty) {
          final json = jsonDecode(respBody);
          if (json is Map && json['data'] is Map && json['data']['token'] != null) {
            _token = '${json['data']['token']}';
            _tokenExpiry = DateTime.now().add(const Duration(hours: 12));
            return _token;
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // Fallback ke token bawaan
    }

    return _token;
  }

  /// Request POST API ShortTV dengan body terenkripsi RC4
  Future<Map<String, dynamic>> _postEncrypted(
    String path,
    Map<String, dynamic> body, {
    String lang = 'id',
    String locale = 'id_ID',
    String country = 'ID',
  }) async {
    final token = await _ensureToken();
    final deviceId = ShortTvConfig.defaultDeviceId;
    final rc4Key = ShortTvConfig.defaultRc4Key;

    final encBodyHex = ShortTvCrypto.rc4EncryptHex(jsonEncode(body), rc4Key);

    final headers = {
      'isEncrypt': 'true',
      'channel': 'googleplay',
      'deviceId': deviceId,
      'clientPlatform': 'android',
      'TraceId': _randomUuid(),
      'Authorization': token,
      'language': lang,
      'locale': locale,
      'timeZone': 'Asia/Jakarta',
      'model': '2201116PG',
      'systemVersion': '14',
      'androidVersion': '34',
      'mcc': '510',
      'environment': 'prod',
      'buildValue': '328',
      'afVersion': '1',
      'hasProxy': 'false',
      'resolution': '1080x2400',
      'system_country_code': country,
      'isR': 'false',
      'isE': 'false',
      'isD': 'false',
      'vefCode': ShortTvCrypto.calculateVefCode(deviceId),
      'Content-Type': 'application/json;charset=utf-8',
      'User-Agent': 'okhttp/4.11.0',
    };

    Object? lastError;
    final hosts = ShortTvConfig.fallbackHosts.isNotEmpty
        ? ShortTvConfig.fallbackHosts
        : [ShortTvConfig.baseUrl];

    for (final host in hosts) {
      final client = HttpClient();
      try {
        final uri = Uri.parse('$host/$path');
        final req = await client.postUrl(uri).timeout(ShortTvConfig.timeout);
        headers.forEach((k, v) => req.headers.set(k, v));
        req.write(encBodyHex);
        final resp = await req.close().timeout(ShortTvConfig.timeout);
        final respBody = await resp.transform(utf8.decoder).join();

        if (resp.statusCode == 200 && respBody.isNotEmpty) {
          final isEnc = resp.headers.value('isEncrypt') == 'true';
          if (isEnc) {
            final jsonResp = jsonDecode(respBody);
            final encResult = jsonResp['result'] ?? '';
            if (encResult is String && encResult.isNotEmpty) {
              final decStr = ShortTvCrypto.rc4DecryptHex(encResult, rc4Key);
              final decoded = jsonDecode(decStr);
              if (decoded is Map<String, dynamic>) return decoded;
              if (decoded is Map) return Map<String, dynamic>.from(decoded);
            }
          } else {
            final decoded = jsonDecode(respBody);
            if (decoded is Map<String, dynamic>) return decoded;
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          }
        }
        lastError = Exception('ShortTV HTTP ${resp.statusCode}: $respBody');
      } catch (e) {
        lastError = e;
      } finally {
        client.close(force: true);
      }
    }

    throw Exception('ShortTV request failed for $path: $lastError');
  }

  /// Ekstrak ContentItem dari daftar respons drama ShortTV
  List<ContentItem> _extractItems(List<dynamic> list, String category) {
    final items = <ContentItem>[];
    final seen = <String>{};

    for (final entry in list) {
      if (entry is! Map) continue;
      final id = '${entry['shortPlayId'] ?? entry['id'] ?? ''}';
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);

      final title = '${entry['shortPlayName'] ?? 'Untitled'}';
      final desc = '${entry['summary'] ?? entry['recommendContent'] ?? ''}';
      final cover = '${entry['coverId'] ?? entry['cover'] ?? ''}';
      final totalEps = int.tryParse('${entry['totalEpisodes'] ?? entry['episodeNum'] ?? 1}') ?? 1;

      final tags = <String>[];
      final labelList = entry['labelList'];
      if (labelList is List) {
        for (final lbl in labelList) {
          if (lbl is Map && lbl['labelName'] != null) {
            final name = '${lbl['labelName']}'.trim();
            if (name.isNotEmpty && !tags.contains(name)) tags.add(name);
          }
        }
      }

      items.add(ContentItem(
        id: id,
        title: title,
        source: 'shorttv',
        category: category,
        description: desc,
        posterUrl: cover,
        backdropUrl: cover,
        rating: 8.8,
        episodes: totalEps <= 0 ? 1 : totalEps,
        platformSlug: 'shorttv',
        lang: 'id',
        tags: tags,
      ));
    }

    return items;
  }

  /// Ambil feed konten berdasarkan kategori
  Future<List<ContentItem>> feedForCategory(String category) async {
    final mapping = ShortTvConfig.categoryMapping[category] ??
        ShortTvConfig.categoryMapping['Semua']!;

    try {
      final res = await _postEncrypted(
        'app/search/searchRankingV2',
        {
          'pageNum': 1,
          'pageSize': 30,
          'experimentKey': '',
          'experimentParam': '',
        },
        lang: mapping.lang,
        locale: mapping.locale,
        country: mapping.country,
      );

      final data = res['data'] as Map?;
      final topList = data?['topResponseList'] as List? ?? [];
      final hotList = data?['hotResponseList'] as List? ?? [];
      final allRaw = [...topList, ...hotList];

      return _extractItems(allRaw, category);
    } catch (_) {
      return const [];
    }
  }

  /// Cari drama berdasarkan keyword
  Future<List<ContentItem>> search(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    try {
      final res = await _postEncrypted(
        'app/search/searchPage',
        {
          'pageNum': 1,
          'pageSize': 20,
          'searchText': keyword.trim(),
        },
      );

      final rawList = res['data'] as List? ?? [];
      return _extractItems(rawList, 'Search');
    } catch (_) {
      return const [];
    }
  }

  /// Ambil daftar episode drama ShortTV
  Future<List<LiveGoEpisode>> episodeList(String seriesId) async {
    final spId = int.tryParse(seriesId) ?? 0;
    if (spId <= 0) return const [];

    try {
      final res = await _postEncrypted(
        'app/hiDrama/dramaListV4',
        {
          'shortPlayId': spId,
          'pageNum': 1,
          'pageSize': 150,
        },
      );

      final data = res['data'] as Map?;
      final rawList = data?['dramaListResponseList'] as List? ?? [];
      final episodes = <LiveGoEpisode>[];

      for (var i = 0; i < rawList.length; i++) {
        final ep = rawList[i];
        if (ep is! Map) continue;
        final dreamId = '${ep['id'] ?? ep['dramaId'] ?? ''}';
        final epNum = int.tryParse('${ep['episodeNum'] ?? i + 1}') ?? (i + 1);

        if (dreamId.isNotEmpty) {
          episodes.add(LiveGoEpisode(
            id: dreamId,
            index: epNum,
            title: 'Episode $epNum',
          ));
        }
      }

      return episodes;
    } catch (_) {
      return const [];
    }
  }

  /// Ambil URL stream video untuk suatu episode dengan resolusi yang diminta
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final dreamId = int.tryParse(episodeId) ?? 0;
    if (dreamId <= 0) {
      throw Exception('ShortTV: dreamId tidak valid ($episodeId)');
    }

    final res = await _postEncrypted(
      'app/forYou/encrypt/playSlideV3',
      {
        'scene': 'shortPlay',
        'dreamId': dreamId,
        'previousEpisodes': 0,
        'nextEpisodes': 1,
      },
    );

    final data = res['data'] as Map?;
    final cur = data?['currentEpisodesReponse'] as Map?;
    if (cur == null) {
      throw Exception('ShortTV: currentEpisodesReponse kosong ($seriesId/$episodeId)');
    }

    final rawVideoUrl = '${cur['videoUrl'] ?? ''}';
    if (rawVideoUrl.isEmpty) {
      throw Exception('ShortTV: videoUrl kosong ($seriesId/$episodeId)');
    }

    Map<String, dynamic> videoMap = {};
    try {
      final decoded = jsonDecode(rawVideoUrl);
      if (decoded is Map<String, dynamic>) {
        videoMap = decoded;
      } else if (decoded is Map) {
        videoMap = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      if (rawVideoUrl.startsWith('http')) {
        return ShortTvStreamProxy.instance.wrapM3u8Url(rawVideoUrl);
      }
    }

    String? selectedUrl;
    final qNorm = (quality ?? '').toLowerCase().replaceAll('p', '');

    if (qNorm.isNotEmpty && qNorm != 'auto') {
      if (qNorm.contains('1080') && videoMap['video_1080'] != null) {
        selectedUrl = '${videoMap['video_1080']}';
      } else if (qNorm.contains('720') && videoMap['video_720'] != null) {
        selectedUrl = '${videoMap['video_720']}';
      } else if (qNorm.contains('480') && videoMap['video_480'] != null) {
        selectedUrl = '${videoMap['video_480']}';
      } else if (qNorm.contains('360')) {
        // Fallback untuk 360p memakai 480p yang paling ringan di ShortTV
        selectedUrl = '${videoMap['video_480'] ?? videoMap['video_720'] ?? videoMap.values.first}';
      }
    }

    selectedUrl ??= '${videoMap['video_720'] ?? videoMap['video_480'] ?? videoMap['video_1080'] ?? videoMap.values.first}';

    if (selectedUrl.startsWith('http')) {
      return ShortTvStreamProxy.instance.wrapM3u8Url(selectedUrl);
    }

    throw Exception('ShortTV: URL stream tidak ditemukan ($seriesId/$episodeId)');
  }

  /// Ekstra metadata episode (resolusi & unlock info)
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    return const DramaEpisodeExtras(
      qualities: [
        DramaQuality(label: '1080p', resolution: '1080x1920 (FHD)'),
        DramaQuality(label: '720p', resolution: '720x1280 (HD)'),
        DramaQuality(label: '480p', resolution: '480x854 (Standar)'),
        DramaQuality(label: '360p', resolution: '360x640 (Cepat)'),
      ],
      unlocked: true,
    );
  }
}
