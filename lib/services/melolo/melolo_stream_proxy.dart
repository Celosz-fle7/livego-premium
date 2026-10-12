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

  /// Diagnostik terakhir untuk ditampilkan di UI saat error
  static String lastDiagnostic = '';

  HttpServer? _server;
  int _port = 0;
  final Map<String, String> _fileRegistry = {}; // token -> filePath
  final Map<String, Completer<void>> _readyCompleters = {}; // token -> siap
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
      unawaited(pruneAllCaches());
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

      // Streaming mode: tunggu file siap (maks 60 detik) agar player tidak timeout
      final completer = _readyCompleters[token];
      if (completer != null && !completer.isCompleted) {
        try {
          await completer.future.timeout(const Duration(seconds: 60));
        } catch (_) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          await request.response.close();
          return;
        }
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
    String? quality,
  }) async {
    await _ensureServer();

    // Dapatkan direktori cache lokal
    Directory? cacheDir;
    try {
      cacheDir = await getTemporaryDirectory();
    } catch (_) {
      cacheDir = Directory.systemTemp;
    }

    final targetDir = Directory('${cacheDir.path}/livego_melolo_cache_v4');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final sanitizedEp = episodeId.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
    final sanitizedSeries = seriesId.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
    final qSuffix = (quality != null && quality.isNotEmpty && quality.toLowerCase() != 'auto')
        ? '_${quality.toLowerCase()}'
        : '';
    final decryptedFile = File('${targetDir.path}/${sanitizedSeries}_${sanitizedEp}$qSuffix.mp4');
    final token = 'melolo_${sanitizedSeries}_${sanitizedEp}$qSuffix.mp4';

    // Jika file sudah didekripsi dan valid (> 100KB), gunakan langsung
    if (await decryptedFile.exists()) {
      final size = await decryptedFile.length();
      if (size > 102400) {
        _fileRegistry[token] = decryptedFile.path;
        return 'http://127.0.0.1:$_port/$token';
      }
    }

    // Ekstrak AES Key dari spade_a
    final aesKey = MeloloCencDecryptor.extractKeyFromSpadeA(spadeA);
    if (aesKey == null) {
      debugPrint('LIVEGO MELOLO: gagal mengekstrak kunci AES dari spade_a, fallback ke URL asli');
      return rawVideoUrl;
    }

    // STREAMING MODE: daftarkan token & kembalikan URL proxy LANGSUNG,
    // download+decrypt jalan di background. Player tidak perlu tunggu.
    _fileRegistry[token] = decryptedFile.path;
    final completer = Completer<void>();
    _readyCompleters[token] = completer;
    unawaited(_downloadAndDecrypt(
      seriesId: seriesId,
      episodeId: episodeId,
      rawVideoUrl: rawVideoUrl,
      aesKey: aesKey,
      decryptedFile: decryptedFile,
      token: token,
      completer: completer,
    ));
    return 'http://127.0.0.1:$_port/$token';
  }

  /// Download + decrypt di background untuk streaming mode.
  Future<void> _downloadAndDecrypt({
    required String seriesId,
    required String episodeId,
    required String rawVideoUrl,
    required Uint8List aesKey,
    required File decryptedFile,
    required String token,
    required Completer<void> completer,
  }) async {
    try {

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
    // ===== DIAGNOSTIK DOWNLOAD =====
    final dlSize = rawBytes.length;
    String fileHeader = 'N/A';
    if (dlSize >= 12) {
      fileHeader = String.fromCharCodes(rawBytes.sublist(4, 12));
    }
    // ignore: avoid_print
    print('LIVEGO MELOLO DIAG: downloaded $dlSize bytes, header="$fileHeader"');
    // ===== END DIAGNOSTIK =====
    if (dlSize < 1024) {
      lastDiagnostic = 'Download gagal: hanya $dlSize bytes (header: $fileHeader)';
      throw Exception('Ukuran video Melolo terlalu kecil ($dlSize bytes). $lastDiagnostic');
    }

    // Dekripsi CENC in-place menggunakan Pure Dart
    final decryptedBytes = MeloloCencDecryptor.decryptMp4Bytes(rawBytes, aesKey);
    // ===== DIAGNOSTIK DECRYPT + VALIDASI =====
    String decHeader = 'N/A';
    bool hasMoov = false;
    bool hasMdat = false;
    if (decryptedBytes.length >= 12) {
      decHeader = String.fromCharCodes(decryptedBytes.sublist(4, 12));
      // Cek box penting: moov dan mdat harus ada di seluruh file MP4
      hasMoov = MeloloCencDecryptor.findBox(decryptedBytes, 'moov', 0, decryptedBytes.length) >= 0;
      hasMdat = MeloloCencDecryptor.findBox(decryptedBytes, 'mdat', 0, decryptedBytes.length) >= 0;
    }
    lastDiagnostic = 'DL:${dlSize}B hdr:$fileHeader | Dec hdr:$decHeader moov:$hasMoov mdat:$hasMdat';
    // ignore: avoid_print
    print('LIVEGO MELOLO DIAG: $lastDiagnostic');
    if (!hasMoov || !hasMdat) {
      lastDiagnostic = 'File MP4 rusak setelah decrypt! $lastDiagnostic';
      throw Exception('Hasil decrypt Melolo tidak valid (moov:$hasMoov mdat:$hasMdat). $lastDiagnostic');
    }
    // ===== END DIAGNOSTIK =====

    // Tulis ke file cache
    await decryptedFile.writeAsBytes(decryptedBytes, flush: true);

    // LRU Cache eviction: batasi maksimal 6 episode terakhir di HP/TV agar memori tidak membengkak
    unawaited(_pruneCache(decryptedFile.parent, maxFiles: 6));

    debugPrint('LIVEGO MELOLO: berhasil dekripsi episode $episodeId (${decryptedBytes.length} bytes)');
    if (!completer.isCompleted) completer.complete();
    } catch (e) {
      debugPrint('LIVEGO MELOLO background download error: $e');
      _fileRegistry.remove(token);
      _readyCompleters.remove(token);
      if (!completer.isCompleted) completer.completeError(e);
    }
  }

  /// Rolling LRU Cache Cleanup persis seperti AVMDL ByteDance:
  /// Membatasi cache maksimal [maxFiles] episode terakhir.
  /// Episode terlama otomatis dihapus bergantian agar memori HP/TV tetap lega.
  static Future<void> _pruneCache(Directory cacheDir, {int maxFiles = 6}) async {
    try {
      if (!await cacheDir.exists()) return;
      final entities = await cacheDir.list().toList();
      final mp4Files = <File>[];
      for (final e in entities) {
        if (e is File && e.path.endsWith('.mp4')) {
          mp4Files.add(e);
        }
      }

      if (mp4Files.length <= maxFiles) return;

      final fileStats = <File, DateTime>{};
      for (final f in mp4Files) {
        try {
          final stat = await f.stat();
          fileStats[f] = stat.modified;
        } catch (_) {}
      }

      mp4Files.sort((a, b) {
        final timeA = fileStats[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = fileStats[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeA.compareTo(timeB);
      });

      while (mp4Files.length > maxFiles) {
        final oldest = mp4Files.removeAt(0);
        try {
          await oldest.delete();
          debugPrint('LIVEGO MELOLO CACHE: LRU evict ${oldest.path.split('/').last}');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('LIVEGO MELOLO CACHE prune error: $e');
    }
  }

  /// Pembersihan menyeluruh untuk menjaga penyimpanan:
  /// 1. Menghapus folder cache Melolo versi terdahulu (v1, v2, v3, playback_cache).
  /// 2. Merampingkan cache v4 terkini dengan rolling LRU (default max 6 files).
  /// Jika [maxFiles] bernilai 0, seluruh file sementara di cache v4 ikut dihapus.
  static Future<void> pruneAllCaches({int maxFiles = 6}) async {
    try {
      Directory? cacheDir;
      try {
        cacheDir = await getTemporaryDirectory();
      } catch (_) {
        cacheDir = Directory.systemTemp;
      }

      final legacyDirs = [
        'livego_melolo_cache',
        'livego_melolo_cache_v2',
        'livego_melolo_cache_v3',
        'melolo_playback_cache',
      ];

      for (final name in legacyDirs) {
        final dir = Directory('${cacheDir.path}/$name');
        if (await dir.exists()) {
          try {
            await dir.delete(recursive: true);
            debugPrint('LIVEGO MELOLO CACHE: dihapus direktori usang $name');
          } catch (_) {}
        }
      }

      final targetDir = Directory('${cacheDir.path}/livego_melolo_cache_v4');
      await _pruneCache(targetDir, maxFiles: maxFiles);
    } catch (e) {
      debugPrint('LIVEGO MELOLO pruneAllCaches error: $e');
    }
  }
}
