import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:livego_premium/services/melolo/melolo_cenc_decryptor.dart';
import 'package:livego_premium/services/melolo/melolo_progressive_proxy.dart';

// Differential test: jalur progressive (parseMoov + decryptRangeInPlace +
// MeloloProgressiveProxy) harus byte-identik dengan jalur lama
// (decryptMp4Bytes) yang sudah terbukti jalan di device.
//
// MP4 sintetis: ftyp + moov (2 trak: video encv 3 sample, audio enca 2 sample)
// + mdat. Varian moov-depan dan moov-belakang.

final _testKey = Uint8List.fromList(List<int>.generate(16, (i) => i * 7 + 1));
final _videoSizes = [100, 250, 64];
final _audioSizes = [50, 80];
final _videoIvs = [
  Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
  Uint8List.fromList([9, 10, 11, 12, 13, 14, 15, 16]),
  Uint8List.fromList([17, 18, 19, 20, 21, 22, 23, 24]),
];
final _audioIvs = [
  Uint8List.fromList([31, 32, 33, 34, 35, 36, 37, 38]),
  Uint8List.fromList([39, 40, 41, 42, 43, 44, 45, 46]),
];

Uint8List _u32(int n) =>
    Uint8List.fromList([(n >> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff]);

Uint8List _box(String type, Uint8List payload) {
  final out = BytesBuilder();
  out.add(_u32(payload.length + 8));
  out.add(ascii.encode(type));
  out.add(payload);
  return out.toBytes();
}

Uint8List _zeros(int n) => Uint8List(n);

Uint8List _buildTrak({
  required String entryType,
  required List<int> sizes,
  required int chunkOffset,
  required List<Uint8List> ivs,
}) {
  final stsdPayload = BytesBuilder()
    ..add(_u32(0))
    ..add(_u32(1))
    ..add(_box(entryType, _zeros(32)));
  final stsd = _box('stsd', stsdPayload.toBytes());

  final stszPayload = BytesBuilder()
    ..add(_u32(0))
    ..add(_u32(0))
    ..add(_u32(sizes.length));
  for (final s in sizes) {
    stszPayload.add(_u32(s));
  }
  final stsz = _box('stsz', stszPayload.toBytes());

  final stco = _box('stco', (BytesBuilder()..add(_u32(0))..add(_u32(1))..add(_u32(chunkOffset))).toBytes());

  final stsc = _box(
    'stsc',
    (BytesBuilder()..add(_u32(0))..add(_u32(1))..add(_u32(1))..add(_u32(sizes.length))..add(_u32(1))).toBytes(),
  );

  final sencPayload = BytesBuilder()
    ..add(_u32(0))
    ..add(_u32(ivs.length));
  for (final iv in ivs) {
    sencPayload.add(iv);
  }
  final senc = _box('senc', sencPayload.toBytes());

  final stbl = _box('stbl', (BytesBuilder()..add(stsd)..add(stsz)..add(stco)..add(stsc)..add(senc)).toBytes());
  final minf = _box('minf', stbl);
  final mdia = _box('mdia', (BytesBuilder()..add(_box('mdhd', _zeros(20)))..add(_box('hdlr', _zeros(20)))..add(minf)).toBytes());
  return _box('trak', (BytesBuilder()..add(_box('tkhd', _zeros(20)))..add(mdia)).toBytes());
}

Uint8List _buildMoov(int videoChunkOff, int audioChunkOff) {
  final trakV = _buildTrak(entryType: 'encv', sizes: _videoSizes, chunkOffset: videoChunkOff, ivs: _videoIvs);
  final trakA = _buildTrak(entryType: 'enca', sizes: _audioSizes, chunkOffset: audioChunkOff, ivs: _audioIvs);
  return _box('moov', (BytesBuilder()..add(_box('mvhd', _zeros(100)))..add(trakV)..add(trakA)).toBytes());
}

/// File plaintext: ftyp + moov + mdat (moov depan) atau ftyp + mdat + moov.
Uint8List _buildPlaintext({required bool moovFirst}) {
  // Ukuran moov tidak bergantung nilai stco -> bangun sekali untuk ukur.
  final moovProbe = _buildMoov(0, 0);
  final ftyp = _box('ftyp', (BytesBuilder()..add(ascii.encode('isom'))..add(_u32(0))..add(ascii.encode('isom'))..add(ascii.encode('iso2'))).toBytes());

  final videoTotal = _videoSizes.reduce((a, b) => a + b);
  final audioTotal = _audioSizes.reduce((a, b) => a + b);
  final rng = Random(42);
  final sampleData = Uint8List.fromList(List<int>.generate(videoTotal + audioTotal, (_) => rng.nextInt(256)));

  final int videoChunkOff;
  final int audioChunkOff;
  if (moovFirst) {
    videoChunkOff = ftyp.length + moovProbe.length + 8;
  } else {
    videoChunkOff = ftyp.length + 8;
  }
  audioChunkOff = videoChunkOff + videoTotal;

  final moov = _buildMoov(videoChunkOff, audioChunkOff);
  final mdat = _box('mdat', sampleData);
  final out = BytesBuilder();
  out.add(ftyp);
  if (moovFirst) {
    out.add(moov);
    out.add(mdat);
  } else {
    out.add(mdat);
    out.add(moov);
  }
  return out.toBytes();
}

/// Balik _decryptSpadeInner agar bisa membuat spade_a untuk key sembarang.
String _craftSpadeA(Uint8List key) {
  final hexKey = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final decoded = Uint8List.fromList([0x30, ...ascii.encode(hexKey)]); // '0' + 32 hex
  // Invert _decryptSpadeInner: result[i] = ((s[i]^buf[i]) - bitCount(i) - 21) mod-ish
  final spadeKey = Uint8List(decoded.length);
  final buf = Uint8List(2 + decoded.length);
  buf[0] = 0xFA;
  buf[1] = 0x55;
  for (var i = 0; i < decoded.length; i++) {
    var bc = 0;
    var v = i - ((i >> 1) & 0x55555555);
    v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
    bc = (((v + (v >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
    final want = decoded[i] + bc + 21;
    final xored = want <= 255 ? want : want - 255;
    final b = i < 2 ? buf[i] : spadeKey[i - 2];
    spadeKey[i] = xored ^ b;
    buf[2 + i] = spadeKey[i];
  }
  final r0 = spadeKey[0] ^ spadeKey[1] ^ 48; // paddingLen = 0
  final raw = Uint8List.fromList([r0, ...spadeKey]);
  return base64.encode(raw);
}

/// Server lokal yang melayani [data] dengan dukungan HTTP Range 206.
Future<HttpServer> _serveWithRange(Uint8List data) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final res = req.response;
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.contentType = ContentType('video', 'mp4');
    final range = req.headers.value(HttpHeaders.rangeHeader);
    if (range != null && range.startsWith('bytes=')) {
      final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      if (m != null) {
        final start = int.parse(m.group(1)!);
        final endStr = m.group(2);
        final end = (endStr != null && endStr.isNotEmpty) ? int.parse(endStr) : data.length - 1;
        final vs = start.clamp(0, data.length - 1);
        final ve = end.clamp(vs, data.length - 1);
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $vs-$ve/${data.length}');
        res.headers.contentLength = ve - vs + 1;
        res.add(data.sublist(vs, ve + 1));
        await res.close();
        return;
      }
    }
    res.statusCode = HttpStatus.ok;
    res.headers.contentLength = data.length;
    res.add(data);
    await res.close();
  });
  return server;
}

/// Cari (start, size) box moov dengan parse box berurutan dari awal file.
({int start, int size}) _moovBounds(Uint8List file) {
  var off = 0;
  while (off + 8 <= file.length) {
    final size = (file[off] << 24) | (file[off + 1] << 16) | (file[off + 2] << 8) | file[off + 3];
    final type = ascii.decode(file.sublist(off + 4, off + 8));
    if (type == 'moov') return (start: off, size: size);
    if (size < 8) throw StateError('box corrupt di offset $off');
    off += size;
  }
  throw StateError('moov tidak ditemukan');
}

Future<Uint8List> _httpGet(String url, {String? range}) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    if (range != null) req.headers.set('Range', range);
    final res = await req.close();
    final builder = BytesBuilder(copy: false);
    await for (final c in res) {
      builder.add(c);
    }
    return builder.takeBytes();
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('Melolo progressive decrypt', () {
    test('spade_a crafting round-trip', () {
      final spadeA = _craftSpadeA(_testKey);
      expect(MeloloCencDecryptor.extractKeyFromSpadeA(spadeA), _testKey);
    });

    test('parseMoov sample table matches synthetic layout (moov depan)', () {
      final plain = _buildPlaintext(moovFirst: true);
      final bounds = _moovBounds(plain);
      expect(bounds.start, 24); // setelah ftyp
      final info = MeloloCencDecryptor.parseMoov(
        plain.sublist(bounds.start, bounds.start + bounds.size),
        bounds.start,
      );
      expect(info, isNotNull);
      expect(info!.samples.length, 5);
      // Video: 3 sample @ mdat data start; audio: 2 sample setelah video.
      final mdatData = bounds.start + bounds.size + 8;
      expect(info.samples[0].offset, mdatData);
      expect(info.samples[0].size, 100);
      expect(info.samples[1].offset, mdatData + 100);
      expect(info.samples[1].size, 250);
      expect(info.samples[2].offset, mdatData + 350);
      expect(info.samples[2].size, 64);
      expect(info.samples[3].offset, mdatData + 414);
      expect(info.samples[3].size, 50);
      expect(info.samples[4].offset, mdatData + 464);
      expect(info.samples[4].size, 80);
      expect(info.samples[0].iv, _videoIvs[0]);
      expect(info.samples[3].iv, _audioIvs[0]);
    });

    test('decryptRangeInPlace matches decryptMp4Bytes (full + partial + moov)', () {
      final plain = _buildPlaintext(moovFirst: true);
      final bounds = _moovBounds(plain);
      final roundKeys = MeloloCencDecryptor.roundKeysFor(_testKey);
      final info = MeloloCencDecryptor.parseMoov(
        plain.sublist(bounds.start, bounds.start + bounds.size),
        bounds.start,
      );
      expect(info, isNotNull);

      // Enkripsi: CTR simetris -> decryptRangeInPlace pada plaintext = ciphertext.
      final encrypted = Uint8List.fromList(plain);
      MeloloCencDecryptor.decryptRangeInPlace(encrypted, 0, info!.samples, roundKeys);

      // Jalur lama (oracle).
      final expected = MeloloCencDecryptor.decryptMp4Bytes(Uint8List.fromList(encrypted), _testKey);

      // Jalur baru: full range.
      final fullNew = Uint8List.fromList(encrypted);
      MeloloCencDecryptor.decryptRangeInPlace(fullNew, 0, info.samples, roundKeys);
      // Moov region diganti sanitized moov (seperti jalur lama).
      fullNew.setRange(info.moovStart, info.moovEnd, info.sanitizedMoov);
      expect(fullNew, expected);

      // Jalur baru: partial ranges harus sama dengan slice jalur lama.
      final ranges = [
        [0, 100],
        [10, 30], // dalam ftyp
        [info.moovStart - 10, info.moovStart + 50], // straddle ftyp/moov
        [info.moovStart, info.moovEnd - 1], // seluruh moov
        [info.moovEnd, info.moovEnd + 200], // awal mdat
        [info.samples[1].offset + 7, info.samples[1].offset + 100], // tengah sample
        [info.samples[2].offset - 5, info.samples[3].offset + 20], // straddle 2 sample + gap
        [info.samples[4].offset, info.samples[4].offset + 79], // sample terakhir utuh
        [plain.length - 30, plain.length - 1], // tail file
      ];
      for (final r in ranges) {
        final start = r[0];
        final end = r[1];
        final slice = Uint8List.fromList(encrypted.sublist(start, end + 1));
        if (start >= info.moovStart && start < info.moovEnd) {
          // Range dalam moov -> serve sanitized moov.
          final takeEnd = end < info.moovEnd ? end : info.moovEnd - 1;
          expect(
            info.sanitizedMoov.sublist(start - info.moovStart, takeEnd - info.moovStart + 1),
            expected.sublist(start, takeEnd + 1),
          );
          continue;
        }
        MeloloCencDecryptor.decryptRangeInPlace(slice, start, info.samples, roundKeys);
        expect(slice, expected.sublist(start, end + 1), reason: 'range $start-$end');
      }
    });

    test('progressive proxy e2e: moov depan', () async {
      final plain = _buildPlaintext(moovFirst: true);
      final bounds = _moovBounds(plain);
      final info = MeloloCencDecryptor.parseMoov(
        plain.sublist(bounds.start, bounds.start + bounds.size),
        bounds.start,
      );
      expect(info, isNotNull);
      final roundKeys = MeloloCencDecryptor.roundKeysFor(_testKey);
      final encrypted = Uint8List.fromList(plain);
      MeloloCencDecryptor.decryptRangeInPlace(encrypted, 0, info!.samples, roundKeys);
      final expected = MeloloCencDecryptor.decryptMp4Bytes(Uint8List.fromList(encrypted), _testKey);

      final origin = await _serveWithRange(encrypted);
      try {
        final proxyUrl = await MeloloProgressiveProxy.instance.prepareProgressiveUrl(
          seriesId: 'test',
          episodeId: 'e1',
          rawVideoUrl: 'http://127.0.0.1:${origin.port}/video.mp4',
          spadeA: _craftSpadeA(_testKey),
        );
        expect(await _httpGet(proxyUrl, range: 'bytes=0-99'), expected.sublist(0, 100));
        expect(await _httpGet(proxyUrl, range: 'bytes=700-800'), expected.sublist(700, 801));
        expect(await _httpGet(proxyUrl), expected);
      } finally {
        await origin.close(force: true);
      }
    });

    test('progressive proxy e2e: moov belakang', () async {
      final plain = _buildPlaintext(moovFirst: false);
      // Moov ada di akhir: cari posisinya.
      final bounds = _moovBounds(plain);
      final info = MeloloCencDecryptor.parseMoov(
        plain.sublist(bounds.start, bounds.start + bounds.size),
        bounds.start,
      );
      expect(info, isNotNull);
      final roundKeys = MeloloCencDecryptor.roundKeysFor(_testKey);
      final encrypted = Uint8List.fromList(plain);
      MeloloCencDecryptor.decryptRangeInPlace(encrypted, 0, info!.samples, roundKeys);
      final expected = MeloloCencDecryptor.decryptMp4Bytes(Uint8List.fromList(encrypted), _testKey);

      final origin = await _serveWithRange(encrypted);
      try {
        final proxyUrl = await MeloloProgressiveProxy.instance.prepareProgressiveUrl(
          seriesId: 'test',
          episodeId: 'e2',
          rawVideoUrl: 'http://127.0.0.1:${origin.port}/video.mp4',
          spadeA: _craftSpadeA(_testKey),
        );
        expect(await _httpGet(proxyUrl, range: 'bytes=0-99'), expected.sublist(0, 100));
        expect(await _httpGet(proxyUrl, range: 'bytes=700-800'), expected.sublist(700, 801));
        expect(await _httpGet(proxyUrl), expected);
      } finally {
        await origin.close(force: true);
      }
    });
  });
}
