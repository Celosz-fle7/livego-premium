import 'dart:convert';
import 'dart:io';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'melolo_config.dart';
import 'melolo_stream_proxy.dart';

/// Error auth Melolo: server menolak identitas perangkat (risk control /
/// sesi tidak login). Dilempar sebagai tipe khusus supaya UI bisa
/// menampilkan pesan yang jelas, bukan gagal diam / daftar kosong.
/// Melolo tidak punya handshake refresh — identitasnya adalah kredensial
/// perangkat di config, jadi tidak ada yang bisa di-retry otomatis di sini.
class MeloloAuthException implements Exception {
  final String message;
  const MeloloAuthException(this.message);
  @override
  String toString() => 'MeloloAuthException: $message';
}

/// Respons server Melolo yang menandakan identitas perangkat ditolak.
bool meloloResponseLooksLikeAuth({Object? code, String? message}) {
  if (code == 4001 || code == '4001' || code == 101000 || code == '101000') {
    return true;
  }
  final m = (message ?? '').toUpperCase();
  return m.contains('RISK_CONTROL') ||
      m.contains('USER_NOT_LOGIN') ||
      m.contains('NOT_LOGIN') ||
      m.contains('NOT LOGIN');
}

/// HTTP Client untuk Melolo API (https://api.tmtreader.com).
/// Meniru permintaan jaringan resmi Melolo untuk discovery, episode, dan pemutaran stream.
class MeloloClient {
  Map<String, String> get _commonParams => {
        'aid': MeloloConfig.aid,
        'device_id': MeloloConfig.deviceId,
        'iid': MeloloConfig.iid,
        'app_name': MeloloConfig.appName,
        'version_code': MeloloConfig.versionCode,
        'version_name': MeloloConfig.versionName,
        'device_platform': MeloloConfig.devicePlatform,
        'os': MeloloConfig.os,
        'ssmix': MeloloConfig.ssmix,
        'device_type': MeloloConfig.deviceType,
        'device_brand': MeloloConfig.deviceBrand,
        'language': MeloloConfig.language,
        'os_api': MeloloConfig.osApi,
        'os_version': MeloloConfig.osVersion,
        'openudid': MeloloConfig.openudid,
        'manifest_version_code': MeloloConfig.manifestVersionCode,
        'resolution': MeloloConfig.resolution,
        'dpi': MeloloConfig.dpi,
        'update_version_code': MeloloConfig.updateVersionCode,
        'current_region': MeloloConfig.currentRegion,
        'carrier_region': MeloloConfig.carrierRegion,
        'app_language': MeloloConfig.appLanguage,
        'sys_language': MeloloConfig.sysLanguage,
        'app_region': MeloloConfig.appRegion,
        'sys_region': MeloloConfig.sysRegion,
        'mcc_mnc': MeloloConfig.mccMnc,
        'carrier_region_v2': MeloloConfig.carrierRegionV2,
        'user_language': MeloloConfig.userLanguage,
        'time_zone': MeloloConfig.timeZone,
        'ui_language': MeloloConfig.uiLanguage,
        'cdid': MeloloConfig.cdid,
        'channel': MeloloConfig.channel,
        'ac': MeloloConfig.ac,
      };

  void _applyHeaders(HttpHeaders headers) {
    headers.set('User-Agent', MeloloConfig.userAgent);
    headers.set('Accept', 'application/json; charset=utf-8,application/x-protobuf');
    headers.set('X-Xs-From-Web', 'false');
  }

  /// Respons 2xx pun bisa membawa penolakan auth (code 4001 / risk control).
  /// Lempar tipe khusus supaya pemanggil (player) menampilkan pesan jelas.
  void _throwIfAuthError(Map<String, dynamic> decoded) {
    final msg = '${decoded['msg'] ?? decoded['message'] ?? ''}';
    if (meloloResponseLooksLikeAuth(code: decoded['code'], message: msg)) {
      throw MeloloAuthException(
        'Melolo menolak sesi perangkat ini ($msg). Coba lagi nanti — kalau '
        'terus gagal, server butuh identitas perangkat baru.',
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    Object? lastError;
    final hosts = MeloloConfig.fallbackHosts.isNotEmpty
        ? MeloloConfig.fallbackHosts
        : [MeloloConfig.baseUrl];

    for (final host in hosts) {
      final uri = Uri.parse(host).replace(
        path: path,
        queryParameters: {
          ..._commonParams,
          ...query,
        },
      );

      final client = HttpClient();
      try {
        final request = await client.getUrl(uri).timeout(MeloloConfig.timeout);
        _applyHeaders(request.headers);
        final response = await request.close().timeout(MeloloConfig.timeout);
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (body.trim().isEmpty) return <String, dynamic>{};
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            _throwIfAuthError(decoded);
            return decoded;
          }
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            _throwIfAuthError(map);
            return map;
          }
          return <String, dynamic>{'data': decoded};
        }
        if (meloloResponseLooksLikeAuth(message: body)) {
          throw MeloloAuthException(
            'Melolo menolak sesi perangkat ini. Coba lagi nanti — kalau '
            'terus gagal, server butuh identitas perangkat baru.',
          );
        }
        lastError = Exception('Melolo GET ${response.statusCode} $path ($host): $body');
      } catch (e) {
        lastError = e;
      } finally {
        client.close(force: true);
      }
    }

    throw Exception('Melolo GET failed on all hosts ($path): $lastError');
  }

  Future<Map<String, dynamic>> _postForm(
    String path,
    Map<String, String> body, {
    Map<String, String>? extraQuery,
  }) async {
    Object? lastError;
    final hosts = MeloloConfig.fallbackHosts.isNotEmpty
        ? MeloloConfig.fallbackHosts
        : [MeloloConfig.baseUrl];

    for (final host in hosts) {
      final uri = Uri.parse(host).replace(
        path: path,
        queryParameters: {
          ..._commonParams,
          ...?extraQuery,
        },
      );

      final client = HttpClient();
      try {
        final request = await client.postUrl(uri).timeout(MeloloConfig.timeout);
        _applyHeaders(request.headers);
        request.headers.set(
          'Content-Type',
          'application/x-www-form-urlencoded; charset=UTF-8',
        );
        if (body.isNotEmpty) {
          request.write(Uri(queryParameters: body).query);
        }
        final response = await request.close().timeout(MeloloConfig.timeout);
        final respBody = await response.transform(utf8.decoder).join();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (respBody.trim().isEmpty) return <String, dynamic>{};
          final decoded = jsonDecode(respBody);
          if (decoded is Map<String, dynamic>) {
            _throwIfAuthError(decoded);
            return decoded;
          }
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            _throwIfAuthError(map);
            return map;
          }
          return <String, dynamic>{'data': decoded};
        }
        if (meloloResponseLooksLikeAuth(message: respBody)) {
          throw MeloloAuthException(
            'Melolo menolak sesi perangkat ini. Coba lagi nanti — kalau '
            'terus gagal, server butuh identitas perangkat baru.',
          );
        }
        lastError = Exception('Melolo POST ${response.statusCode} $path ($host): $respBody');
      } catch (e) {
        lastError = e;
      } finally {
        client.close(force: true);
      }
    }

    throw Exception('Melolo POST failed on all hosts ($path): $lastError');
  }

  /// Ekstrak daftar ContentItem dari respons search / kategori
  List<ContentItem> _extractBooks(Map<String, dynamic> res, String category) {
    final data = res['data'] as Map?;
    final searchData = data?['search_data'] as List? ?? [];
    final items = <ContentItem>[];
    final seenIds = <String>{};

    for (final block in searchData) {
      if (block is! Map) continue;
      final books = block['books'] as List? ?? [];
      for (final book in books) {
        if (book is! Map) continue;
        final id = '${book['book_id'] ?? ''}';
        if (id.isEmpty || seenIds.contains(id)) continue;
        seenIds.add(id);

        final title = '${book['book_name'] ?? 'Untitled'}';
        final desc = '${book['abstract'] ?? ''}';
        final cover = '${book['thumb_url'] ?? book['cover'] ?? book['book_cover'] ?? ''}';
        final episodesCount = int.tryParse(
              '${book['serial_count'] ?? book['total_episodes'] ?? book['episode_cnt'] ?? 1}',
            ) ??
            1;

        // Ekstrak tag genre resmi dari metadata server 'category_info'
        final itemTags = <String>[];
        final rawCatInfo = book['category_info'];
        if (rawCatInfo is String && rawCatInfo.trim().isNotEmpty) {
          try {
            final decodedCats = jsonDecode(rawCatInfo);
            if (decodedCats is List) {
              for (final catItem in decodedCats) {
                if (catItem is Map) {
                  final tagName = '${catItem['Name'] ?? catItem['name'] ?? ''}'.trim();
                  if (tagName.isNotEmpty && !itemTags.contains(tagName)) {
                    itemTags.add(tagName);
                  }
                }
              }
            }
          } catch (_) {}
        } else if (rawCatInfo is List) {
          for (final catItem in rawCatInfo) {
            if (catItem is Map) {
              final tagName = '${catItem['Name'] ?? catItem['name'] ?? ''}'.trim();
              if (tagName.isNotEmpty && !itemTags.contains(tagName)) {
                itemTags.add(tagName);
              }
            }
          }
        }

        items.add(ContentItem(
          id: id,
          title: title,
          source: 'melolo',
          category: category,
          description: desc,
          posterUrl: cover,
          backdropUrl: cover,
          rating: 8.5,
          episodes: episodesCount <= 0 ? 1 : episodesCount,
          platformSlug: 'melolo',
          lang: 'id',
          tags: itemTags.isNotEmpty ? itemTags : ContentItem.extractTags(book),
        ));
      }
    }

    return items;
  }

  /// Ambil feed konten untuk kategori dengan pagination awal
  Future<List<ContentItem>> feedForCategory(String category) async {
    final queryTerm = MeloloConfig.categoryQueryMap[category] ?? category;
    final allItems = <ContentItem>[];
    final seen = <String>{};

    // Ambil 2 batch pertama (offset 0 dan offset 20) agar katalog melimpah
    for (final offset in [0, 20]) {
      try {
        final res = await _getJson(MeloloConfig.searchEndpoint, {
          'query': queryTerm,
          'offset': '$offset',
          'limit': '20',
        });
        final batch = _extractBooks(res, category);
        for (final item in batch) {
          if (seen.add(item.id)) {
            allItems.add(item);
          }
        }
      } catch (_) {
        break;
      }
    }

    return allItems;
  }

  /// Satu halaman feed kategori (pagination ikut server).
  /// offset = (page-1)*pageSize, limit = pageSize. Lempar error kalau
  /// request gagal (pemanggil membedakan error vs halaman kosong).
  Future<({List<ContentItem> items, bool hasMore})> feedPage(
    String category, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryTerm = MeloloConfig.categoryQueryMap[category] ?? category;
    final res = await _getJson(MeloloConfig.searchEndpoint, {
      'query': queryTerm,
      'offset': '${(page - 1) * pageSize}',
      'limit': '$pageSize',
    });
    final batch = _extractBooks(res, category);
    return (items: batch, hasMore: batch.length >= pageSize);
  }

  /// Pencarian konten Melolo
  Future<List<ContentItem>> search(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    try {
      final res = await _getJson(MeloloConfig.searchEndpoint, {
        'query': keyword.trim(),
        'offset': '0',
        'limit': '30',
      });
      return _extractBooks(res, 'Search');
    } catch (_) {
      return const [];
    }
  }

  /// Ambil daftar episode drama Melolo
  Future<List<LiveGoEpisode>> episodeList(String seriesId) async {
    final res = await _postForm(
      MeloloConfig.videoDetailEndpoint,
      {'series_id': seriesId},
    );

    final data = res['data'] as Map?;
    final videoData = data?['video_data'] as Map?;
    final rawList = videoData?['video_list'] as List? ?? [];

    final episodes = <LiveGoEpisode>[];
    var fallbackIndex = 1;

    for (final item in rawList) {
      if (item is! Map) continue;
      final vid = '${item['vid'] ?? item['id'] ?? ''}';
      if (vid.isEmpty) continue;

      final idx = int.tryParse(
            '${item['vid_index'] ?? item['episode'] ?? fallbackIndex}',
          ) ??
          fallbackIndex;

      episodes.add(LiveGoEpisode(
        id: vid,
        index: idx,
        title: 'Episode $idx',
      ));
      fallbackIndex++;
    }

    return episodes;
  }

  /// Ambil URL stream video untuk suatu episode dengan resolusi yang diminta
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final res = await _postForm(
      MeloloConfig.videoModelEndpoint,
      {
        'series_id': seriesId,
        'video_id': episodeId,
      },
    );

    final data = res['data'] as Map?;
    if (data == null) {
      throw Exception('Melolo: data video model kosong ($seriesId/$episodeId)');
    }

    dynamic rawVm = data['video_model'] ?? data['videoModel'];
    if (rawVm is String) {
      try {
        rawVm = jsonDecode(rawVm);
      } catch (_) {}
    }

    final vm = rawVm is Map ? rawVm : <dynamic, dynamic>{};

    final videoList = vm['video_list'];

    Map? selectedQuality;
    if (videoList is Map && videoList.isNotEmpty) {
      if (quality != null && quality.isNotEmpty && quality.toLowerCase() != 'auto') {
        final qNorm = quality.toLowerCase().replaceAll('p', '');
        for (final entry in videoList.values) {
          if (entry is Map) {
            final def = '${entry['definition'] ?? entry['quality'] ?? ''}'.toLowerCase();
            final h = '${entry['vheight'] ?? ''}';
            final w = '${entry['vwidth'] ?? ''}';
            if (def.contains(qNorm) || h.contains(qNorm) || w.contains(qNorm)) {
              selectedQuality = entry;
              break;
            }
          }
        }
      }
      selectedQuality ??= (videoList['video_1'] ?? videoList.values.first) as Map?;
    } else if (videoList is List && videoList.isNotEmpty) {
      selectedQuality = videoList.first as Map?;
    }

    if (selectedQuality != null) {
      final rawMainUrl = '${selectedQuality['main_url'] ?? selectedQuality['backup_url_1'] ?? ''}';
      final spadeA = '${selectedQuality['spade_a'] ?? vm['spade_a'] ?? ''}';

      if (rawMainUrl.isNotEmpty) {
        var videoUrl = _tryBase64Decode(rawMainUrl);
        if (!videoUrl.startsWith('http')) {
          videoUrl = rawMainUrl;
        }

        if (videoUrl.startsWith('http')) {
          if (spadeA.isNotEmpty) {
            try {
              return await MeloloStreamProxy.instance.prepareStreamUrl(
                seriesId: seriesId,
                episodeId: episodeId,
                rawVideoUrl: videoUrl,
                spadeA: spadeA,
                quality: quality,
              );
            } catch (e, stack) {
              // Catat error kegagalan decrypt/proxy agar tidak crash senyap
              // ignore: avoid_print
              print('LIVEGO Melolo stream proxy error: $e\n$stack');
              rethrow;
            }
          }
          return videoUrl;
        }
      }
    }

    throw Exception('Melolo: URL stream tidak ditemukan ($seriesId/$episodeId)');
  }

  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    return const DramaEpisodeExtras(
      qualities: [
        DramaQuality(label: '720p', resolution: '720x1280 (HD)'),
        DramaQuality(label: '540p', resolution: '540x960 (Standar)'),
        DramaQuality(label: '480p', resolution: '480x854 (Hemat)'),
        DramaQuality(label: '360p', resolution: '360x640 (Cepat)'),
        DramaQuality(label: '240p', resolution: '240x426 (Ringan)'),
      ],
      unlocked: true,
    );
  }

  String _tryBase64Decode(String str) {
    try {
      var s = str.replaceAll('-', '+').replaceAll('_', '/').trim();
      final mod = s.length % 4;
      if (mod != 0) {
        s += '=' * (4 - mod);
      }
      return utf8.decode(base64.decode(s));
    } catch (_) {
      return '';
    }
  }

  /// Batch fetch video model untuk beberapa episode sekaligus
  Future<Map<String, dynamic>> multiVideoModel({
    required String seriesId,
    required List<String> episodeIds,
  }) async {
    return _postForm(
      MeloloConfig.multiVideoModelEndpoint,
      {
        'series_id': seriesId,
        'video_id_list': jsonEncode(episodeIds),
      },
    );
  }
}
