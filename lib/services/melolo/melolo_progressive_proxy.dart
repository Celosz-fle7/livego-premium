import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'melolo_cenc_decryptor.dart';
import 'melolo_config.dart';

/// Progressive streaming proxy untuk Melolo: decrypt on-the-fly per range.
///
/// Beda dengan jalur download-full (download full -> decrypt -> serve):
/// 1. Ambil + parse `moov` saja (header, ~1-2MB) via HTTP Range.
/// 2. Setiap request Range dari ExoPlayer -> fetch range yang sama dari source,
///    decrypt sample yang overlap, serve. File tidak pernah didownload utuh.
/// 3. Kalau moov tidak bisa diparse / server tidak support Range -> throw,
///    pemanggil fallback ke jalur download full.
///
/// Layout byte file bersih == file ter-enkripsi (sanitasi moov mengganti box
/// dengan ukuran yang sama), jadi mapping range 1:1 tanpa konversi offset.
class MeloloProgressiveProxy {
  static MeloloProgressiveProxy? _instance;
  static MeloloProgressiveProxy get instance => _instance ??= MeloloProgressiveProxy._();

  HttpServer? _server;
  int _port = 0;
  final Map<String, _ProgressiveSession> _sessions = {};

  MeloloProgressiveProxy._();

  Future<void> ensureRunning() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('LIVEGO MELOLO PROGRESSIVE: running on 127.0.0.1:$_port');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LIVEGO MELOLO PROGRESSIVE error: $e');
      });
    } catch (e) {
      debugPrint('LIVEGO MELOLO PROGRESSIVE bind failed: $e');
      rethrow;
    }
  }

  /// Siapkan session progressive + prefetch moov.
  /// Throw kalau progressive tidak bisa dipakai (pemanggil fallback ke full download).
  Future<String> prepareProgressiveUrl({
    required String seriesId,
    required String episodeId,
    required String rawVideoUrl,
    required String spadeA,
    String? quality,
  }) async {
    await ensureRunning();

    final aesKey = MeloloCencDecryptor.extractKeyFromSpadeA(spadeA);
    if (aesKey == null) {
      throw Exception('Melolo progressive: gagal ekstrak kunci AES dari spade_a');
    }

    final sanitizedEp = episodeId.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
    final sanitizedSeries = seriesId.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
    final qSuffix = (quality != null && quality.isNotEmpty && quality.toLowerCase() != 'auto')
        ? '_${quality.toLowerCase()}'
        : '';
    final token = 'melolo_prog_${sanitizedSeries}_${sanitizedEp}$qSuffix.mp4';

    final session = _ProgressiveSession(rawVideoUrl: rawVideoUrl, aesKey: aesKey);
    _sessions[token] = session;
    try {
      await session.ensureMoov().timeout(const Duration(seconds: 12));
    } catch (e) {
      _sessions.remove(token);
      session.dispose();
      rethrow;
    }
    return 'http://127.0.0.1:$_port/$token';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final token = request.uri.pathSegments.isNotEmpty ? request.uri.pathSegments.last : '';
      final session = _sessions[token];
      if (session == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      await session.ensureMoov();
      final total = session.totalLength;
      if (total == null || total <= 0) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }

      // HEAD: header saja, tanpa body.
      if (request.method == 'HEAD') {
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.headers.contentLength = total;
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.contentType = ContentType('video', 'mp4');

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          final start = int.parse(match.group(1)!);
          final endStr = match.group(2);
          final end = (endStr != null && endStr.isNotEmpty) ? int.parse(endStr) : total - 1;
          final validStart = start.clamp(0, total - 1);
          final validEnd = end.clamp(validStart, total - 1);

          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $validStart-$validEnd/$total',
          );
          request.response.headers.contentLength = validEnd - validStart + 1;
          await session.serveRange(request.response, validStart, validEnd);
          return;
        }
      }

      // Tanpa Range: stream dari awal sampai habis.
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentLength = total;
      await session.serveRange(request.response, 0, total - 1);
    } catch (e) {
      debugPrint('LIVEGO MELOLO PROGRESSIVE serve error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }
}

/// Satu episode: moov yang sudah diparse + koneksi ke source.
class _ProgressiveSession {
  static const int _headSize = 2 * 1024 * 1024;
  static const int _chunkSize = 512 * 1024;
  static const List<int> _tailSizes = [
    2 * 1024 * 1024,
    4 * 1024 * 1024,
    8 * 1024 * 1024,
    16 * 1024 * 1024,
  ];

  final String rawVideoUrl;
  final Uint8List aesKey;
  late final List<List<Uint8List>> _roundKeys = MeloloCencDecryptor.roundKeysFor(aesKey);
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  MeloloMoovInfo? _moov;
  int? _totalLength;
  Future<void>? _moovFuture;

  _ProgressiveSession({required this.rawVideoUrl, required this.aesKey});

  int? get totalLength => _totalLength;

  void dispose() {
    try {
      _client.close(force: true);
    } catch (_) {}
  }

  Future<void> ensureMoov() => _moovFuture ??= _loadMoov();

  // --- Moov loading ---

  Future<void> _loadMoov() async {
    final head = await _fetchRange(0, _headSize - 1);
    final headBytes = head.bytes;
    if (head.totalLength != null) _totalLength = head.totalLength;

    // Parse box berurutan dari awal: cari moov, atau mdat (tanda moov di akhir).
    var off = 0;
    var moovAtEnd = false;
    while (off + 8 <= headBytes.length) {
      var size = _readUint32(headBytes, off);
      final type = String.fromCharCodes(headBytes.sublist(off + 4, off + 8));
      var headerSize = 8;
      if (size == 1) {
        if (off + 16 > headBytes.length) break;
        size = _readUint64(headBytes, off + 8);
        headerSize = 16;
      } else if (size == 0) {
        size = headBytes.length - off;
      }
      if (size < headerSize) break;
      if (type == 'moov') {
        if (off + size <= headBytes.length) {
          _setMoov(headBytes.sublist(off, off + size), off);
          return;
        }
        // Moov terpotong head -> fetch persis [off, off+size).
        final full = await _fetchRange(off, off + size - 1);
        _setMoov(full.bytes, off);
        return;
      }
      if (type == 'mdat') {
        moovAtEnd = true;
        break;
      }
      off += size;
    }

    if (!moovAtEnd) {
      // Moov tidak ketemu di head (mis. setelah box free/wide besar):
      // coba tail juga sebelum menyerah.
      moovAtEnd = true;
    }

    // Moov di akhir file: cari via tail yang membesar.
    final total = _totalLength ?? await _fetchTotalLength();
    _totalLength = total;
    for (final tailSize in _tailSizes) {
      final tailStart = total - tailSize < 0 ? 0 : total - tailSize;
      final tail = await _fetchRange(tailStart, total - 1);
      final found = _findMoovInTail(tail.bytes, tailStart);
      if (found != null) {
        _setMoov(found.bytes, found.start);
        return;
      }
      if (tailStart == 0) break;
    }
    throw Exception('Melolo progressive: moov tidak ditemukan di tail file');
  }

  void _setMoov(Uint8List moovBytes, int moovStart) {
    final info = MeloloCencDecryptor.parseMoov(moovBytes, moovStart);
    if (info == null) {
      throw Exception('Melolo progressive: moov tidak bisa diparse (format tidak didukung)');
    }
    if (info.samples.isEmpty) {
      throw Exception('Melolo progressive: moov tanpa sample');
    }
    _moov = info;
    debugPrint(
      'LIVEGO MELOLO PROGRESSIVE: moov siap start=$moovStart size=${info.moovEnd - info.moovStart} samples=${info.samples.length}',
    );
  }

  /// Cari moov di chunk tail. Validasi dengan parseMoov agar signature
  /// 'moov' palsu di dalam data mdat tidak kepakai.
  ({Uint8List bytes, int start})? _findMoovInTail(Uint8List tail, int tailStart) {
    var pos = 0;
    while (pos < tail.length - 4) {
      final idx = _indexOf(tail, 'moov', pos);
      if (idx < 0) return null;
      if (idx >= 4) {
        final size = _readUint32(tail, idx - 4);
        if (size > 8 && idx - 4 + size <= tail.length) {
          final candidate = tail.sublist(idx - 4, idx - 4 + size);
          if (MeloloCencDecryptor.parseMoov(candidate, tailStart + idx - 4) != null) {
            return (bytes: candidate, start: tailStart + idx - 4);
          }
        }
      }
      pos = idx + 4;
    }
    return null;
  }

  Future<int> _fetchTotalLength() async {
    // Range 1 byte saja: Content-Range memberi total tanpa download file.
    final head = await _fetchRange(0, 0);
    if (head.totalLength != null && head.totalLength! > 0) {
      return head.totalLength!;
    }
    throw Exception('Melolo progressive: tidak bisa dapat panjang file');
  }

  // --- Range serving ---

  /// Stream [start, end] inklusif ke [response], per chunk 512KB.
  Future<void> serveRange(HttpResponse response, int start, int end) async {
    await ensureMoov();
    final moov = _moov;
    if (moov == null) throw StateError('Moov belum siap');

    var pos = start;
    while (pos <= end) {
      final chunkEnd = (pos + _chunkSize - 1 < end) ? pos + _chunkSize - 1 : end;
      if (pos >= moov.moovStart && pos < moov.moovEnd) {
        // Dari moov yang sudah disanitasi (tidak perlu fetch source).
        final takeEnd = chunkEnd < moov.moovEnd - 1 ? chunkEnd : moov.moovEnd - 1;
        response.add(moov.sanitizedMoov.sublist(pos - moov.moovStart, takeEnd - moov.moovStart + 1));
        pos = takeEnd + 1;
      } else {
        // Fetch dari source, jangan lewati batas moov.
        var fetchEnd = chunkEnd;
        if (pos < moov.moovStart && fetchEnd >= moov.moovStart) {
          fetchEnd = moov.moovStart - 1;
        }
        final data = (await _fetchRange(pos, fetchEnd)).bytes;
        MeloloCencDecryptor.decryptRangeInPlace(data, pos, moov.samples, _roundKeys);
        response.add(data);
        pos = fetchEnd + 1;
      }
    }
    await response.close();
  }

  // --- Source fetch ---

  /// Fetch [start, end] inklusif dari source via HTTP Range.
  /// Throw [_NoRangeSupport] kalau server balas 200 (mengabaikan Range).
  Future<({Uint8List bytes, int? totalLength})> _fetchRange(int start, int end) async {
    final req = await _client.getUrl(Uri.parse(rawVideoUrl));
    req.headers.set('Range', 'bytes=$start-$end');
    req.headers.set('User-Agent', MeloloConfig.userAgent);
    req.headers.set('Accept', '*/*');
    final res = await req.close().timeout(const Duration(seconds: 30));

    if (res.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      throw Exception('Melolo progressive: range $start-$end di luar file');
    }
    if (res.statusCode == HttpStatus.ok) {
      await res.drain<void>();
      throw const _NoRangeSupport();
    }
    if (res.statusCode != HttpStatus.partialContent) {
      await res.drain<void>();
      throw HttpException('Melolo progressive: HTTP ${res.statusCode}');
    }

    int? total;
    final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)').firstMatch(contentRange);
      if (match != null) total = int.tryParse(match.group(1)!);
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return (bytes: builder.takeBytes(), totalLength: total);
  }

  // --- Helpers ---

  static int _readUint32(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static int _readUint64(Uint8List data, int offset) {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v = (v << 8) | data[offset + i];
    }
    return v;
  }

  static int _indexOf(Uint8List data, String pattern, int start) {
    final p = pattern.codeUnits;
    final limit = data.length - p.length;
    for (var i = start; i <= limit; i++) {
      var match = true;
      for (var j = 0; j < p.length; j++) {
        if (data[i + j] != p[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}

/// Server source mengabaikan header Range (balas 200, bukan 206).
class _NoRangeSupport implements Exception {
  const _NoRangeSupport();

  @override
  String toString() => 'Server tidak mendukung HTTP Range';
}
