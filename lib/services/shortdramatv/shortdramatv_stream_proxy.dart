import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'shortdramatv_config.dart';

/// Local streaming proxy untuk ShortDramaTV.
/// Menerima request ke /resource.mp4?src={base64_url} dan forward ke CDN.
/// Mendukung HTTP Range requests (206 Partial Content) untuk video seeking.
class ShortDramaTvStreamProxy {
  static ShortDramaTvStreamProxy? _instance;
  static ShortDramaTvStreamProxy get instance =>
      _instance ??= ShortDramaTvStreamProxy._();

  HttpServer? _server;
  int _port = 0;
  Completer<void>? _initCompleter;

  // In-memory cache untuk chunk video (LRU sederhana)
  final Map<String, Uint8List> _chunkCache = {};
  final List<String> _chunkKeys = [];
  static const int _maxCachedChunks = 50;

  ShortDramaTvStreamProxy._();

  Future<void> ensureRunning() => _ensureServer();

  Future<void> _ensureServer() async {
    if (_server != null) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      try {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          ShortDramaTvConfig.localProxyPort,
          shared: true,
        );
      } catch (_) {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }
      _port = _server!.port;
      _server!.listen(_handleRequest, onError: (e) {
        // Log error diam-diam
      });
      completer.complete();
    } catch (e) {
      completer.complete();
    }
    return completer.future;
  }

  void _handleRequest(HttpRequest request) async {
    try {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', '*');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final path = request.uri.path;
      if (path == '/resource.mp4' || path == '/sv.mp4') {
        final encoded = request.uri.queryParameters['src'];
        if (encoded == null || encoded.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }

        // Decode base64 URL
        String targetUrl;
        try {
          final padded = encoded +
              ('=' * ((4 - encoded.length % 4) % 4));
          targetUrl = utf8.decode(base64Decode(padded));
        } catch (_) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }

        // Fetch dari CDN dengan Range header
        final client = HttpClient();
        try {
          final req = await client.getUrl(Uri.parse(targetUrl));
          req.headers.set('User-Agent', 'okhttp/4.11.0');

          // Forward Range header kalau ada
          final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
          if (rangeHeader != null) {
            req.headers.set(HttpHeaders.rangeHeader, rangeHeader);
          }

          final res = await req.close();

          if (res.statusCode == 200 || res.statusCode == 206) {
            request.response.statusCode = res.statusCode;
            request.response.headers.contentType = ContentType('video', 'mp4');
            request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

            // Forward Content-Range kalau ada
            final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
            if (contentRange != null) {
              request.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
            }

            final contentLength = res.headers.value(HttpHeaders.contentLengthHeader);
            if (contentLength != null) {
              request.response.headers.contentLength = int.tryParse(contentLength) ?? -1;
            }

            await res.pipe(request.response);
          } else {
            request.response.statusCode = res.statusCode;
            await request.response.close();
          }
        } finally {
          client.close(force: true);
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Wrap direct CDN URL ke local proxy URL
  Future<String> wrapUrl(String directUrl) async {
    await _ensureServer();
    final encoded = base64Encode(utf8.encode(directUrl));
    return 'http://127.0.0.1:$_port/resource.mp4?src=$encoded&sl=1';
  }

  void clearCache() {
    _chunkCache.clear();
    _chunkKeys.clear();
  }
}
