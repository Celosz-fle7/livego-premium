import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'cinemaid_config.dart';

/// Proxy lokal untuk stream CinemaID.
///
/// App asli (com.movieph.bj.playvibes) memakai libvindictus.so yang
/// menjalankan proxy di 127.0.0.1:7000. Semua vod_url dari API
/// diformat menjadi:
///   http://127.0.0.1:7000/resource.m3u8?src=<base64(real_url)>
///
/// Proxy ini mereplika perilaku tersebut di Dart:
/// 1. Terima request /resource.m3u8?src=<base64>
/// 2. Decode base64 -> URL asli CDN
/// 3. Fetch dari CDN dengan header yang benar
/// 4. Untuk m3u8: rewrite URL segmen agar lewat proxy juga
/// 5. Serve ke player
class CinemaIdStreamProxy {
  static CinemaIdStreamProxy? _instance;
  static CinemaIdStreamProxy get instance =>
      _instance ??= CinemaIdStreamProxy._();

  HttpServer? _server;
  final Completer<void> _initCompleter = Completer<void>();

  CinemaIdStreamProxy._();

  /// Pastikan server proxy jalan di 127.0.0.1:7000
  Future<void> ensureRunning() async {
    if (_server != null) return;
    if (_initCompleter.isCompleted) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 7000);
      debugPrint('LIVEGO CINEMAID PROXY: running on 127.0.0.1:7000');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LIVEGO CINEMAID PROXY error: $e');
      });
      _initCompleter.complete();
    } catch (e) {
      debugPrint('LIVEGO CINEMAID PROXY bind failed: $e');
      _initCompleter.completeError(e);
    }
    return _initCompleter.future;
  }

  void _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final srcParam = request.uri.queryParameters['src'];

      if (path == '/resource.m3u8' && srcParam != null && srcParam.isNotEmpty) {
        await _serveResource(request, srcParam);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (e) {
      debugPrint('LIVEGO CINEMAID PROXY serve error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Serve resource dari CDN melalui proxy.
  Future<void> _serveResource(HttpRequest request, String srcB64) async {
    String realUrl;
    try {
      realUrl = utf8.decode(base64.decode(srcB64));
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    debugPrint('LIVEGO CINEMAID PROXY: fetching $realUrl');

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(realUrl));
      // Header seperti app asli untuk bypass 403 CDN
      req.headers.set('User-Agent', CinemaIdConfig.userAgent);
      req.headers.set('Referer', CinemaIdConfig.referer);
      req.headers.set('Accept', '*/*');

      final res = await req.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
            'LIVEGO CINEMAID PROXY: CDN returned ${res.statusCode} for $realUrl');
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
        return;
      }

      final contentType = res.headers.contentType?.mimeType ?? '';
      final isM3u8 = realUrl.contains('.m3u8') || contentType.contains('mpegurl');

      if (isM3u8) {
        // Baca m3u8, rewrite URL segmen agar lewat proxy
        final body = await res.transform(utf8.decoder).join();
        final rewritten = _rewriteM3u8(body, realUrl);
        final bytes = utf8.encode(rewritten);
        request.response.headers.contentType =
            ContentType('application', 'x-mpegURL');
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      } else {
        // Stream langsung (segmen .ts atau file lain)
        final length = res.contentLength;
        if (length > 0) {
          request.response.headers.contentLength = length;
        }
        if (res.headers.contentType != null) {
          request.response.headers.contentType = res.headers.contentType!;
        }
        await res.pipe(request.response);
      }
    } catch (e) {
      debugPrint('LIVEGO CINEMAID PROXY fetch error: $e');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  }

  /// Rewrite URL di dalam m3u8 agar segmen juga lewat proxy.
  String _rewriteM3u8(String m3u8, String baseUrl) {
    final base = Uri.parse(baseUrl);
    final lines = m3u8.split('\n');
    final out = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        // Handle EXT-X-KEY URI jika ada
        if (trimmed.startsWith('#EXT-X-KEY')) {
          out.add(_rewriteKeyUri(trimmed, base));
        } else {
          out.add(line);
        }
      } else {
        // Baris URL segmen -> resolve ke absolute lalu bungkus proxy
        final absolute = base.resolve(trimmed).toString();
        final b64 = base64.encode(utf8.encode(absolute));
        out.add('${CinemaIdConfig.localProxyBaseUrl}/resource.m3u8?src=$b64');
      }
    }
    return out.join('\n');
  }

  /// Rewrite URI di dalam tag EXT-X-KEY jika ada enkripsi.
  String _rewriteKeyUri(String line, Uri base) {
    final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(line);
    if (uriMatch == null) return line;
    final keyUri = uriMatch.group(1)!;
    final absolute = base.resolve(keyUri).toString();
    final b64 = base64.encode(utf8.encode(absolute));
    final proxied =
        '${CinemaIdConfig.localProxyBaseUrl}/resource.m3u8?src=$b64';
    return line.replaceFirst('URI="$keyUri"', 'URI="$proxied"');
  }
}
