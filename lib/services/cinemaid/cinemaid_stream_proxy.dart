import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'cinemaid_config.dart';

/// Proxy lokal mandiri untuk stream CinemaID di LiveGo.
///
/// Menggunakan algoritma otentikasi CDN Wangsu / CloudFront (hasil teardown
/// libpp_hls.so):
/// - wsTime: timestamp epoch hex lowercase
/// - wsSecret: md5(cdnSecretKey + uri_path + wsTime)
///
/// Bekerja 100% mandiri di port 7055 tanpa bergantung pada app luar
/// dan tanpa konflik port 7000.
class CinemaIdStreamProxy {
  static CinemaIdStreamProxy? _instance;
  static CinemaIdStreamProxy get instance =>
      _instance ??= CinemaIdStreamProxy._();

  HttpServer? _server;
  Completer<void>? _initCompleter;

  CinemaIdStreamProxy._();

  /// Tanda tangani URL CDN movieph.xrrqe.com dengan parameter wsSecret & wsTime
  /// agar langsung lolos proteksi WAF CloudFront/Wangsu.
  static String signCdnUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final path = uri.path;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final wsTime = nowSec.toRadixString(16).toLowerCase();
      final signSource = utf8.encode('${CinemaIdConfig.cdnSecretKey}$path$wsTime');
      final wsSecret = md5.convert(signSource).toString();

      final existingParams = Map<String, String>.from(uri.queryParameters);
      existingParams.remove('wsSecret');
      existingParams.remove('wsTime');
      existingParams['wsSecret'] = wsSecret;
      existingParams['wsTime'] = wsTime;

      return uri.replace(queryParameters: existingParams).toString();
    } catch (e) {
      debugPrint('LIVEGO CINEMAID PROXY sign error: $e');
      return rawUrl;
    }
  }

  /// Pastikan server proxy mandiri aktif di 127.0.0.1:7055.
  Future<void> ensureRunning() async {
    if (_server != null) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        CinemaIdConfig.localProxyPort,
        shared: true,
      );
      debugPrint('LIVEGO CINEMAID PROXY: running mandiri on 127.0.0.1:${CinemaIdConfig.localProxyPort}');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LIVEGO CINEMAID PROXY error: $e');
      });
      completer.complete();
    } catch (e) {
      debugPrint('LIVEGO CINEMAID PROXY bind notice: $e');
      completer.complete();
    }
    return completer.future;
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

  /// Serve resource dari CDN melalui proxy mandiri LiveGo.
  Future<void> _serveResource(HttpRequest request, String srcB64) async {
    String realUrl;
    try {
      realUrl = utf8.decode(base64.decode(srcB64));
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    // Tanda tangani URL dengan kunci otentikasi CDN
    final signedUrl = signCdnUrl(realUrl);
    debugPrint('LIVEGO CINEMAID PROXY: fetching signed $signedUrl');

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(signedUrl));
      req.headers.set('User-Agent', CinemaIdConfig.userAgent);
      req.headers.set('Referer', CinemaIdConfig.referer);
      req.headers.set('Accept', '*/*');

      // Dukung header Range dari video player
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.isNotEmpty) {
        req.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      }

      final res = await req.close();

      request.response.statusCode = res.statusCode;

      final isM3u8 = realUrl.contains('.m3u8') ||
          (res.headers.contentType?.mimeType.contains('mpegurl') ?? false);

      if (isM3u8 && res.statusCode == HttpStatus.ok) {
        // Baca m3u8 dan rewrite URL segmen agar lewat proxy mandiri
        final body = await res.transform(utf8.decoder).join();
        final rewritten = _rewriteM3u8(body, realUrl);
        final bytes = utf8.encode(rewritten);
        request.response.headers.contentType =
            ContentType('application', 'x-mpegURL');
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      } else {
        // Stream langsung untuk segmen .ts
        if (res.contentLength > 0) {
          request.response.headers.contentLength = res.contentLength;
        }
        if (res.headers.contentType != null) {
          request.response.headers.contentType = res.headers.contentType!;
        }
        final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
        if (contentRange != null) {
          request.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
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

  /// Rewrite URL di dalam m3u8 agar seluruh segmen di-serve melalui proxy mandiri.
  String _rewriteM3u8(String m3u8, String baseUrl) {
    final base = Uri.parse(baseUrl);
    final lines = m3u8.split('\n');
    final out = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        if (trimmed.startsWith('#EXT-X-KEY')) {
          out.add(_rewriteKeyUri(trimmed, base));
        } else {
          out.add(line);
        }
      } else {
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
