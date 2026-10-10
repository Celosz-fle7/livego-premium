import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'melolo_cenc_decryptor.dart';
import 'melolo_config.dart';

/// Embedded Local Streaming Server & Decryption Cache untuk Melolo di LiveGo.
///
/// Cara kerja:
/// 1. Menerima request URL video mentah Melolo + `spade_a` + `seriesId` + `episodeId`.
/// 2. Cek apakah MP4 terdekripsi sudah ada di cache lokal perangkat.
/// 3. Jika belum, unduh file MP4 terenkripsi (~3-4MB), dekripsi in-place menggunakan `MeloloCencDecryptor`.
/// 4. Simpan file MP4 bersih ke cache `melolo_playback_cache/`.
/// 5. Sajikan file melalui `HttpServer` loopback lokal (`127.0.0.1:<port>`) dengan dukungan HTTP 206 Partial Content (Range request)
///    sehingga `VideoPlayerController.networkUrl` (ExoPlayer di Android/TV) dapat melakukan seek, buffer, dan play secara instan tanpa black screen.
class MeloloStreamProxy {
  static MeloloStreamProxy? _instance;
  static MeloloStreamProxy get instance => _instance ??= MeloloStreamProxy._();

  HttpServer? _server;
  int _port = 0;
  final Map<String, String> _fileRegistry = {}; // token -> filePath
  final Completer<void> _initCompleter = Completer<void>();

  MeloloStreamProxy._();

  Future<void> _ensureServer() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('LIVEGO MELOLO PROXY: running on 127.0.0.1:$_port');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LIVEGO MELOLO PROXY error: $e');
      });
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    } catch (e) {
      debugPrint('LIVEGO MELOLO PROXY bind failed: $e');
      if (!_initCompleter.isCompleted) _initCompleter.completeError(e);
    }
  }

  void _handleRequest(HttpRequest request) async {
    try {
      final token = request.uri.pathSegments.isNotEmpty ? request.uri.pathSegments.last : '';
      final filePath = _fileRegistry[token];
      if (filePath == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final length = await file.length();
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.contentType = ContentType('video', 'mp4');

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        // Parse range header: e.g. bytes=0-1024 or bytes=1024-
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          final start = int.parse(match.group(1)!);
          final endStr = match.group(2);
          final end = (endStr != null && endStr.isNotEmpty) ? int.parse(endStr) : length - 1;

          final validStart = start.clamp(0, length - 1);
          final validEnd = end.clamp(validStart, length - 1);
          final chunkLen = validEnd - validStart + 1;

          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $validStart-$validEnd/$length',
          );
          request.response.headers.contentLength = chunkLen;

          final stream = file.openRead(validStart, validEnd + 1);
          await request.response.addStream(stream);
          await request.response.close();
          return;
        }
      }

      // Serve full content
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentLength = length;
      await request.response.addStream(file.openRead());
      await request.response.close();
    } catch (e) {
      debugPrint('LIVEGO MELOLO PROXY serve error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Menyiapkan URL streaming lokal untuk episode Melolo.
  /// Mendekripsi stream terenkripsi secara otomatis dan mengembalikan URL `http://127.0.0.1:<port>/<token>`.
  Future<String> prepareStreamUrl({
    required String seriesId,
    required String episodeId,
    required String rawVideoUrl,
    required String spadeA,
  }) async {
    await _ensureServer();

    // Dapatkan direktori cache lokal
    Directory? cacheDir;
    try {
      cacheDir = await getTemporaryDirectory();
    } catch (_) {
      cacheDir = Directory.systemTemp;
    }

    final targetDir = Directory('${cacheDir.path}/livego_melolo_cache_v3');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final sanitizedEp = episodeId.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
    final sanitizedSeries = seriesId.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
    final decryptedFile = File('${targetDir.path}/${sanitizedSeries}_$sanitizedEp.mp4');

    // Jika file sudah didekripsi dan valid (> 100KB), gunakan langsung
    if (await decryptedFile.exists()) {
      final size = await decryptedFile.length();
      if (size > 102400) {
        final token = 'melolo_${sanitizedSeries}_$sanitizedEp.mp4';
        _fileRegistry[token] = decryptedFile.path;
        return decryptedFile.uri.toString();
      }
    }

    // Ekstrak AES Key dari spade_a
    final aesKey = MeloloCencDecryptor.extractKeyFromSpadeA(spadeA);
    if (aesKey == null) {
      debugPrint('LIVEGO MELOLO: gagal mengekstrak kunci AES dari spade_a, fallback ke URL asli');
      return rawVideoUrl;
    }

    debugPrint('LIVEGO MELOLO: mendownload & mendekripsi video $seriesId/$episodeId...');

    // Unduh payload MP4 terenkripsi
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 15);
    final req = await httpClient.getUrl(Uri.parse(rawVideoUrl));
    req.headers.set('User-Agent', MeloloConfig.userAgent);
    req.headers.set('Accept', '*/*');
    final res = await req.close();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Gagal mengunduh stream Melolo HTTP ${res.statusCode}');
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    httpClient.close(force: true);

    final rawBytes = builder.takeBytes();
    if (rawBytes.length < 1024) {
      throw Exception('Ukuran video Melolo terlalu kecil (${rawBytes.length} bytes)');
    }

    // Dekripsi CENC in-place menggunakan Pure Dart
    final decryptedBytes = MeloloCencDecryptor.decryptMp4Bytes(rawBytes, aesKey);

    // Tulis ke file cache
    await decryptedFile.writeAsBytes(decryptedBytes, flush: true);

    final token = 'melolo_${sanitizedSeries}_$sanitizedEp.mp4';
    _fileRegistry[token] = decryptedFile.path;
    debugPrint('LIVEGO MELOLO: berhasil dekripsi episode $episodeId (${decryptedBytes.length} bytes) -> ${decryptedFile.uri}');

    return decryptedFile.uri.toString();
  }
}
