import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'cinemaid_config.dart';

class CinemaIdClient {
  final HttpClient _httpClient;
  static final Random _random = Random.secure();

  CinemaIdClient({HttpClient? httpClient})
      : _httpClient = httpClient ??
            (HttpClient()
              ..badCertificateCallback = (cert, host, port) => true);

  static String _generateDeviceId() {
    final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<dynamic> postApi(String endpoint, Map<String, dynamic> params) async {
    final uri = Uri.parse('${CinemaIdConfig.baseUrl}$endpoint');
    final request = await _httpClient.postUrl(uri);

    request.headers.set(HttpHeaders.userAgentHeader, CinemaIdConfig.userAgent);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set('app_id', CinemaIdConfig.appId);
    request.headers.set('token', CinemaIdConfig.secretToken);

    final bodyBytes = utf8.encode(jsonEncode(params));
    request.add(bodyBytes);

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    if (responseBody == 'error1' || responseBody.contains('系统出问题啦')) {
      throw HttpException('Server returned error response: $responseBody', uri: uri);
    }

    try {
      return jsonDecode(responseBody);
    } catch (_) {
      return responseBody;
    }
  }

  Future<dynamic> getHomeVideos({int page = 1, int pageSize = 10}) async {
    return postApi('/sunshine/video/showHomePageVideosForPage', {
      'pageNum': page,
      'pageSize': pageSize,
      'app_id': CinemaIdConfig.appId,
      'device_id': _generateDeviceId(),
    });
  }

  Future<dynamic> getCategories() async {
    return postApi('/api/channel/get_list', {
      'app_id': CinemaIdConfig.appId,
      'device_id': _generateDeviceId(),
    });
  }

  Future<dynamic> getVideoDetail(int vodId) async {
    return postApi('/api/vod/info_new', {
      'vod_id': vodId,
      'app_id': CinemaIdConfig.appId,
      'device_id': _generateDeviceId(),
    });
  }
}
