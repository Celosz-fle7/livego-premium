import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'shorttv_crypto.dart';

/// Embedded Local Streaming Server & MPEG-TS Decryption Proxy untuk ShortTV di LiveGo.
///
/// Cara kerja:
/// 1. Mengunduh berkas M3U8 resmi dari Akamai CDN ShortTV.
/// 2. Memetakan URL segmen TS terenkripsi (`/main_X.ts`) ke proxy lokal (`127.0.0.1:<port>/ts?url=...`).
/// 3. Ketika player memuat segmen TS, proxy mengunduh TS mentah, mendekripsi AES-128-CBC
///    menggunakan `ShortTvCrypto.decryptTsSegment` menjadi MPEG-TS standar (Sync byte 0x47).
/// 4. Menyajikan TS bersih ke Video Player LiveGo secara instan dengan HTTP 200/206.
class ShortTvStreamProxy {
  static ShortTvStreamProxy? _instance;
  static ShortTvStreamProxy get instance => _instance ??= ShortTvStreamProxy._();

  HttpServer? _server;
  int _port = 0;
  final Completer<void> _initCompleter = Completer<void>();

  // In-memory LRU cache untuk segmen TS terdekripsi (menghindari download ulang saat seek/loop)
  final Map<String, Uint8List> _tsCache = {};
  final List<String> _tsCacheKeys = [];
  static const int _maxCachedSegments = 30;

  ShortTvStreamProxy._();

  Future<void> _ensureServer() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('LIVEGO SHORTTV PROXY: running on 127.0.0.1:$_port');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LIVEGO SHORTTV PROXY error: $e');
      });
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    } catch (e) {
      debugPrint('LIVEGO SHORTTV PROXY bind failed: $e');
      if (!_initCompleter.isCompleted) _initCompleter.completeError(e);
    }
  }

  void _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path == '/m3u8') {
        final targetUrl = request.uri.queryParameters['url'];
        if (targetUrl == null || targetUrl.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }

        // Unduh dan modifikasi M3U8
        final client = HttpClient();
        try {
          final req = await client.getUrl(Uri.parse(targetUrl));
          req.headers.set('User-Agent', 'okhttp/4.11.0');
          final res = await req.close();
          if (res.statusCode != 200) {
            request.response.statusCode = res.statusCode;
            await request.response.close();
            return;
          }

          final m3u8Content = await res.transform(const SystemEncoding().decoder).join();
          final baseUri = Uri.parse(targetUrl);

          // Rewriting segment URLs
          final lines = m3u8Content.split('\n');
          final modifiedLines = <String>[];

          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith('#')) {
              modifiedLines.add(line);
            } else {
              // Ini adalah path atau URL segmen TS
              final segmentUri = baseUri.resolve(trimmed);
              final proxySegmentUrl =
                  'http://127.0.0.1:$_port/ts?url=${Uri.encodeComponent(segmentUri.toString())}';
              modifiedLines.add(proxySegmentUrl);
            }
          }

          final outputBody = modifiedLines.join('\n');
          request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
          request.response.write(outputBody);
          await request.response.close();
        } finally {
          client.close(force: true);
        }
      } else if (path == '/ts') {
        final targetUrl = request.uri.queryParameters['url'];
        if (targetUrl == null || targetUrl.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }

        Uint8List? cleanData = _tsCache[targetUrl];
        if (cleanData == null) {
          final client = HttpClient();
          try {
            final req = await client.getUrl(Uri.parse(targetUrl));
            req.headers.set('User-Agent', 'okhttp/4.11.0');
            final res = await req.close();
            if (res.statusCode != 200) {
              request.response.statusCode = res.statusCode;
              await request.response.close();
              return;
            }

            final chunks = <List<int>>[];
            await for (final chunk in res) {
              chunks.add(chunk);
            }
            final totalBytes = chunks.fold<int>(0, (sum, c) => sum + c.length);
            final rawBytes = Uint8List(totalBytes);
            int offset = 0;
            for (final c in chunks) {
              rawBytes.setRange(offset, offset + c.length, c);
              offset += c.length;
            }

            // Dekripsi segmen TS ShortTV
            cleanData = ShortTvCrypto.decryptTsSegment(rawBytes);

            // Simpan di in-memory cache
            _tsCache[targetUrl] = cleanData;
            _tsCacheKeys.add(targetUrl);
            if (_tsCacheKeys.length > _maxCachedSegments) {
              final oldKey = _tsCacheKeys.removeAt(0);
              _tsCache.remove(oldKey);
            }
          } finally {
            client.close(force: true);
          }
        }

        request.response.headers.contentType = ContentType('video', 'mp2t');
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.contentLength = cleanData.length;
        request.response.add(cleanData);
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      debugPrint('LIVEGO SHORTTV PROXY request error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Ubah URL m3u8 asli menjadi URL loopback lokal proxy LiveGo
  Future<String> wrapM3u8Url(String originalM3u8Url) async {
    await _ensureServer();
    return 'http://127.0.0.1:$_port/m3u8?url=${Uri.encodeComponent(originalM3u8Url)}';
  }

  /// Bersihkan cache segmen TS saat ganti episode atau keluar player
  void clearSegmentCache() {
    _tsCache.clear();
    _tsCacheKeys.clear();
  }
}
