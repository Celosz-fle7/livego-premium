import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../models/content_item.dart';
import 'freereels_auth.dart';
import 'freereels_config.dart';
import 'freereels_session.dart';

/// HTTP client FreeReels — meniru persis request APK mod.
///
/// - Base: https://apiv2.free-reels.com + prefix /frv2-api (ApiPathInterceptor)
/// - Auth: session dari /anonymous/login (flow APK), signing MD5 per request
/// - Header: set lengkap sesuai HeaderInterceptor + script Python
class FreereelsClient {
  final FreereelsSession _session = FreereelsSession();
  static final _random = Random.secure();

  static String _requestDeviceId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _applyHeaders(HttpHeaders headers) {
    headers.set('User-Agent', FreereelsConfig.userAgent);
    headers.set('Content-Type', 'application/json; charset=UTF-8');
    headers.set('Accept', 'application/json');
    headers.set(
      'Authorization',
      FreereelsAuth.buildAuthorization(
        authKey: _session.authKey,
        authSecret: _session.authSecret,
      ),
    );
    headers.set('app-version', FreereelsConfig.appVersion);
    headers.set('app-name', FreereelsConfig.appName);
    headers.set('device', FreereelsConfig.device);
    headers.set('device-id', _requestDeviceId());
    headers.set('language', FreereelsConfig.language);
    headers.set('country', FreereelsConfig.country);
    headers.set('x-device-model', FreereelsConfig.deviceModel);
    headers.set('screen-width', FreereelsConfig.screenWidth);
    headers.set('screen-height', FreereelsConfig.screenHeight);
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    await _session.ensureLogin();

    final cleanPath = path.startsWith(FreereelsConfig.apiPrefix)
        ? path
        : '${FreereelsConfig.apiPrefix}$path';
    final uri = Uri.parse(FreereelsConfig.baseUrl).replace(
      path: cleanPath,
      queryParameters: query.isEmpty ? null : query,
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(FreereelsConfig.timeout);
      _applyHeaders(request.headers);
      final response = await request.close().timeout(FreereelsConfig.timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('FreeReels ${response.statusCode} ${uri.path}: $body');
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

  /// GET /homepage/v2/tab/index?tab_key=..&position_index=..
  /// Return list ContentItem (id=key, posterUrl=cover).
  Future<List<ContentItem>> tabFeed({
    required String tabKey,
    int positionIndex = 0,
    String category = '',
  }) async {
    final res = await _getJson('/homepage/v2/tab/index', {
      'tab_key': tabKey,
      'position_index': '$positionIndex',
    });

    final code = res['code'];
    if (code != 200 && code != 0) {
      throw Exception('FreeReels code=$code msg=${res['msg']}');
    }

    final items = <ContentItem>[];
    final modules = (res['data'] as Map?)?['items'] as List? ?? [];
    for (final module in modules) {
      final moduleItems = (module as Map?)?['items'] as List? ?? [];
      for (final item in moduleItems) {
        final m = item as Map;
        final key = '${m['key'] ?? ''}';
        if (key.isEmpty) continue;
        items.add(ContentItem(
          id: key,
          title: '${m['title'] ?? 'No title'}',
          source: 'freereels',
          category: category,
          description: '',
          posterUrl: '${m['cover'] ?? ''}',
          backdropUrl: '${m['cover'] ?? ''}',
          rating: 0,
          episodes: 0,
          platformSlug: 'freereels',
          lang: 'id',
        ));
      }
    }
    return items;
  }

  /// Ambil semua series unik dari satu tab (pagination ala script Python).
  Future<List<ContentItem>> allSeriesFromTab({
    required String tabKey,
    required String category,
    int maxPages = 50,
  }) async {
    final seen = <String>{};
    final all = <ContentItem>[];

    for (var page = 0; page < maxPages; page++) {
      final batch = await tabFeed(
        tabKey: tabKey,
        positionIndex: page * 10,
        category: category,
      );
      if (batch.isEmpty) break;

      var added = 0;
      for (final item in batch) {
        if (seen.add(item.id)) {
          all.add(item);
          added++;
        }
      }
      if (added == 0) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return all;
  }
}
