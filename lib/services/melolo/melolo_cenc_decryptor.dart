import 'dart:convert';
import 'dart:typed_data';

/// Dekriptor CENC (Common Encryption, cenc AES-128-CTR) untuk MP4 ByteDance/Melolo.
///
/// Bekerja 100% pure Dart tanpa pustaka C eksternal atau daemon Termux:
/// 1. Dekripsi `spade_a` -> AES-128 key (16 bytes).
/// 2. Parsing struktur MP4 (moov, trak, stsz, stco, stsc, senc).
/// 3. In-place dekripsi setiap video/audio sample menggunakan AES-128-CTR.
/// 4. Ubah FourCC sampel entry: `encv` -> `hvc1` dan `enca` -> `mp4a` agar dipahami ExoPlayer/AVFoundation.
class MeloloCencDecryptor {
  MeloloCencDecryptor._();

  static const List<int> _sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5e, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
  ];

  static const List<int> _rCon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  static int _xtime(int a) => (a & 0x80 != 0) ? (((a << 1) ^ 0x1b) & 0xff) : (a << 1);

  // --- 1. Ekstrak Kunci AES dari spade_a ---

  static int _decodeBase36(int cp) {
    if (cp >= 48 && cp <= 57) return cp - 48;
    if (cp >= 97 && cp <= 122) return cp - 97 + 10;
    return 0xff;
  }

  static int _bitCount(int n) {
    var v = n - ((n >> 1) & 0x55555555);
    v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
    return (((v + (v >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
  }

  static Uint8List _decryptSpadeInner(Uint8List spadeKey) {
    final result = Uint8List(spadeKey.length);
    final buf = Uint8List(2 + spadeKey.length);
    buf[0] = 0xFA;
    buf[1] = 0x55;
    buf.setRange(2, buf.length, spadeKey);

    for (var i = 0; i < spadeKey.length; i++) {
      var val = (spadeKey[i] ^ buf[i]) - _bitCount(i) - 21;
      while (val < 0) {
        val += 0xff;
      }
      result[i] = val % 256;
    }
    return result;
  }

  /// Mengekstrak kunci 16-byte AES-128 dari string base64 `spade_a`
  static Uint8List? extractKeyFromSpadeA(String spadeABase64) {
    try {
      final raw = base64.decode(spadeABase64.trim());
      final length = raw.length;
      if (length < 8) return null;

      final paddingLen = (raw[0] ^ raw[1] ^ raw[2]) - 48;
      if (paddingLen < 0 || paddingLen >= length) return null;

      final innerInput = raw.sublist(1, length - paddingLen);
      final decoded = _decryptSpadeInner(innerInput);
      final skip = _decodeBase36(decoded[0]);
      final msgLen = length - paddingLen - 2;
      final endIdx = 1 + msgLen - skip;

      if (endIdx <= 1 || endIdx > decoded.length) return null;
      final keyHex = utf8.decode(decoded.sublist(1, endIdx), allowMalformed: true);
      return _hexToBytes(keyHex.trim());
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (clean.length != 32) return null;
    final res = Uint8List(16);
    for (var i = 0; i < 32; i += 2) {
      res[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return res;
  }

  // --- 2. AES-128 Key Expansion & ECB Block Encrypt ---

  static List<List<Uint8List>> _expandKey(Uint8List key) {
    final keyCols = <Uint8List>[];
    for (var i = 0; i < 16; i += 4) {
      keyCols.add(Uint8List.fromList(key.sublist(i, i + 4)));
    }
    var i = 1;
    while (keyCols.length < 44) {
      final word = Uint8List.fromList(keyCols.last);
      if (keyCols.length % 4 == 0) {
        final r0 = word[1];
        final r1 = word[2];
        final r2 = word[3];
        final r3 = word[0];
        word[0] = _sBox[r0] ^ _rCon[i];
        word[1] = _sBox[r1];
        word[2] = _sBox[r2];
        word[3] = _sBox[r3];
        i++;
      }
      final prev = keyCols[keyCols.length - 4];
      for (var j = 0; j < 4; j++) {
        word[j] ^= prev[j];
      }
      keyCols.add(word);
    }

    final matrices = <List<Uint8List>>[];
    for (var r = 0; r < 11; r++) {
      matrices.add([
        keyCols[4 * r + 0],
        keyCols[4 * r + 1],
        keyCols[4 * r + 2],
        keyCols[4 * r + 3],
      ]);
    }
    return matrices;
  }

  static void _encryptBlock(
    Uint8List block,
    int offset,
    List<List<Uint8List>> roundKeys,
    Uint8List out,
    int outOffset,
  ) {
    // 4 kolom x 4 baris: s[col][row]
    var s00 = block[offset + 0]; var s01 = block[offset + 1]; var s02 = block[offset + 2]; var s03 = block[offset + 3];
    var s10 = block[offset + 4]; var s11 = block[offset + 5]; var s12 = block[offset + 6]; var s13 = block[offset + 7];
    var s20 = block[offset + 8]; var s21 = block[offset + 9]; var s22 = block[offset + 10]; var s23 = block[offset + 11];
    var s30 = block[offset + 12]; var s31 = block[offset + 13]; var s32 = block[offset + 14]; var s33 = block[offset + 15];

    final rk0 = roundKeys[0];
    s00 ^= rk0[0][0]; s01 ^= rk0[0][1]; s02 ^= rk0[0][2]; s03 ^= rk0[0][3];
    s10 ^= rk0[1][0]; s11 ^= rk0[1][1]; s12 ^= rk0[1][2]; s13 ^= rk0[1][3];
    s20 ^= rk0[2][0]; s21 ^= rk0[2][1]; s22 ^= rk0[2][2]; s23 ^= rk0[2][3];
    s30 ^= rk0[3][0]; s31 ^= rk0[3][1]; s32 ^= rk0[3][2]; s33 ^= rk0[3][3];

    for (var rnd = 1; rnd < 10; rnd++) {
      s00 = _sBox[s00]; s01 = _sBox[s01]; s02 = _sBox[s02]; s03 = _sBox[s03];
      s10 = _sBox[s10]; s11 = _sBox[s11]; s12 = _sBox[s12]; s13 = _sBox[s13];
      s20 = _sBox[s20]; s21 = _sBox[s21]; s22 = _sBox[s22]; s23 = _sBox[s23];
      s30 = _sBox[s30]; s31 = _sBox[s31]; s32 = _sBox[s32]; s33 = _sBox[s33];

      // ShiftRows
      final t1 = s01; s01 = s11; s11 = s21; s21 = s31; s31 = t1;
      final t20 = s02; s02 = s22; s22 = t20;
      final t21 = s12; s12 = s32; s32 = t21;
      final t3 = s33; s33 = s23; s23 = s13; s13 = s03; s03 = t3;

      // MixColumns
      var t = s00 ^ s01 ^ s02 ^ s03; var u = s00;
      s00 ^= t ^ _xtime(s00 ^ s01); s01 ^= t ^ _xtime(s01 ^ s02); s02 ^= t ^ _xtime(s02 ^ s03); s03 ^= t ^ _xtime(s03 ^ u);

      t = s10 ^ s11 ^ s12 ^ s13; u = s10;
      s10 ^= t ^ _xtime(s10 ^ s11); s11 ^= t ^ _xtime(s11 ^ s12); s12 ^= t ^ _xtime(s12 ^ s13); s13 ^= t ^ _xtime(s13 ^ u);

      t = s20 ^ s21 ^ s22 ^ s23; u = s20;
      s20 ^= t ^ _xtime(s20 ^ s21); s21 ^= t ^ _xtime(s21 ^ s22); s22 ^= t ^ _xtime(s22 ^ s23); s23 ^= t ^ _xtime(s23 ^ u);

      t = s30 ^ s31 ^ s32 ^ s33; u = s30;
      s30 ^= t ^ _xtime(s30 ^ s31); s31 ^= t ^ _xtime(s31 ^ s32); s32 ^= t ^ _xtime(s32 ^ s33); s33 ^= t ^ _xtime(s33 ^ u);

      // AddRoundKey
      final rk = roundKeys[rnd];
      s00 ^= rk[0][0]; s01 ^= rk[0][1]; s02 ^= rk[0][2]; s03 ^= rk[0][3];
      s10 ^= rk[1][0]; s11 ^= rk[1][1]; s12 ^= rk[1][2]; s13 ^= rk[1][3];
      s20 ^= rk[2][0]; s21 ^= rk[2][1]; s22 ^= rk[2][2]; s23 ^= rk[2][3];
      s30 ^= rk[3][0]; s31 ^= rk[3][1]; s32 ^= rk[3][2]; s33 ^= rk[3][3];
    }

    // Round 10
    s00 = _sBox[s00]; s01 = _sBox[s01]; s02 = _sBox[s02]; s03 = _sBox[s03];
    s10 = _sBox[s10]; s11 = _sBox[s11]; s12 = _sBox[s12]; s13 = _sBox[s13];
    s20 = _sBox[s20]; s21 = _sBox[s21]; s22 = _sBox[s22]; s23 = _sBox[s23];
    s30 = _sBox[s30]; s31 = _sBox[s31]; s32 = _sBox[s32]; s33 = _sBox[s33];

    final t1 = s01; s01 = s11; s11 = s21; s21 = s31; s31 = t1;
    final t20 = s02; s02 = s22; s22 = t20;
    final t21 = s12; s12 = s32; s32 = t21;
    final t3 = s33; s33 = s23; s23 = s13; s13 = s03; s03 = t3;

    final rk10 = roundKeys[10];
    out[outOffset + 0] = s00 ^ rk10[0][0]; out[outOffset + 1] = s01 ^ rk10[0][1];
    out[outOffset + 2] = s02 ^ rk10[0][2]; out[outOffset + 3] = s03 ^ rk10[0][3];

    out[outOffset + 4] = s10 ^ rk10[1][0]; out[outOffset + 5] = s11 ^ rk10[1][1];
    out[outOffset + 6] = s12 ^ rk10[1][2]; out[outOffset + 7] = s13 ^ rk10[1][3];

    out[outOffset + 8] = s20 ^ rk10[2][0]; out[outOffset + 9] = s21 ^ rk10[2][1];
    out[outOffset + 10] = s22 ^ rk10[2][2]; out[outOffset + 11] = s23 ^ rk10[2][3];

    out[outOffset + 12] = s30 ^ rk10[3][0]; out[outOffset + 13] = s31 ^ rk10[3][1];
    out[outOffset + 14] = s32 ^ rk10[3][2]; out[outOffset + 15] = s33 ^ rk10[3][3];
  }

  // --- 3. MP4 Parsing & CENC Decryption ---

  static int _findBox(Uint8List data, String boxType, int start, int end) {
    final b0 = boxType.codeUnitAt(0);
    final b1 = boxType.codeUnitAt(1);
    final b2 = boxType.codeUnitAt(2);
    final b3 = boxType.codeUnitAt(3);

    final limit = end - 4;
    for (var i = start; i < limit; i++) {
      if (data[i] == b0 && data[i + 1] == b1 && data[i + 2] == b2 && data[i + 3] == b3) {
        return i;
      }
    }
    return -1;
  }

  static int _readUint32(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static void _decryptTrack(
    Uint8List data,
    int trakPos,
    int trakEnd,
    List<List<Uint8List>> roundKeys,
  ) {
    final stszPos = _findBox(data, 'stsz', trakPos, trakEnd);
    if (stszPos < 0) return;
    final scnt = _readUint32(data, stszPos + 12);
    final sizes = List<int>.filled(scnt, 0);
    for (var i = 0; i < scnt; i++) {
      sizes[i] = _readUint32(data, stszPos + 16 + i * 4);
    }

    final stcoPos = _findBox(data, 'stco', trakPos, trakEnd);
    if (stcoPos < 0) return;
    final ccnt = _readUint32(data, stcoPos + 8);
    final chunks = List<int>.filled(ccnt, 0);
    for (var i = 0; i < ccnt; i++) {
      chunks[i] = _readUint32(data, stcoPos + 12 + i * 4);
    }

    final stscPos = _findBox(data, 'stsc', trakPos, trakEnd);
    if (stscPos < 0) return;
    final ecnt = _readUint32(data, stscPos + 8);
    final stscEntries = <List<int>>[];
    for (var i = 0; i < ecnt; i++) {
      final base = stscPos + 12 + i * 12;
      stscEntries.add([
        _readUint32(data, base),
        _readUint32(data, base + 4),
        _readUint32(data, base + 8),
      ]);
    }

    final sencPos = _findBox(data, 'senc', trakPos, trakEnd);
    if (sencPos < 0) return;
    final ivCnt = _readUint32(data, sencPos + 8);
    if (ivCnt != scnt) return;

    // Kalkulasi posisi setiap sample
    var sIdx = 0;
    final sampleOffsets = List<int>.filled(scnt, 0);
    for (var cIdx = 0; cIdx < ccnt; cIdx++) {
      final chunkNo = cIdx + 1;
      var spc = stscEntries.first[1];
      for (final e in stscEntries) {
        if (chunkNo >= e[0]) spc = e[1];
      }
      var currOff = chunks[cIdx];
      for (var s = 0; s < spc; s++) {
        if (sIdx < scnt) {
          sampleOffsets[sIdx] = currOff;
          currOff += sizes[sIdx];
          sIdx++;
        }
      }
    }

    // Dekripsi AES-CTR in-place
    final counterBlock = Uint8List(16);
    final keyStream = Uint8List(16);

    for (var i = 0; i < scnt; i++) {
      final off = sampleOffsets[i];
      final sz = sizes[i];
      final ivOffset = sencPos + 12 + i * 8;

      // 8 bytes IV prefix
      counterBlock[0] = data[ivOffset];
      counterBlock[1] = data[ivOffset + 1];
      counterBlock[2] = data[ivOffset + 2];
      counterBlock[3] = data[ivOffset + 3];
      counterBlock[4] = data[ivOffset + 4];
      counterBlock[5] = data[ivOffset + 5];
      counterBlock[6] = data[ivOffset + 6];
      counterBlock[7] = data[ivOffset + 7];

      var ctr = 0;
      for (var bOff = 0; bOff < sz; bOff += 16) {
        counterBlock[8] = (ctr >> 56) & 0xff;
        counterBlock[9] = (ctr >> 48) & 0xff;
        counterBlock[10] = (ctr >> 40) & 0xff;
        counterBlock[11] = (ctr >> 32) & 0xff;
        counterBlock[12] = (ctr >> 24) & 0xff;
        counterBlock[13] = (ctr >> 16) & 0xff;
        counterBlock[14] = (ctr >> 8) & 0xff;
        counterBlock[15] = ctr & 0xff;

        _encryptBlock(counterBlock, 0, roundKeys, keyStream, 0);

        final rem = (sz - bOff < 16) ? (sz - bOff) : 16;
        for (var j = 0; j < rem; j++) {
          data[off + bOff + j] ^= keyStream[j];
        }
        ctr++;
      }
    }
  }

  /// Mendekripsi stream byte MP4 Melolo secara in-place dan menghasilkan Uint8List file MP4 yang playable.
  static Uint8List decryptMp4Bytes(Uint8List mp4Bytes, Uint8List aesKey) {
    if (mp4Bytes.length < 100) return mp4Bytes;

    // Cari letak traks
    final vTrak = _findBox(mp4Bytes, 'trak', 0, mp4Bytes.length);
    if (vTrak < 0) return mp4Bytes;
    final aTrak = _findBox(mp4Bytes, 'trak', vTrak + 4, mp4Bytes.length);

    final roundKeys = _expandKey(aesKey);

    // Dekripsi video
    _decryptTrack(mp4Bytes, vTrak, aTrak > 0 ? aTrak : mp4Bytes.length, roundKeys);

    // Dekripsi audio
    if (aTrak > 0) {
      _decryptTrack(mp4Bytes, aTrak, mp4Bytes.length, roundKeys);
    }

    // Cari batas atom moov agar modifikasi metadata hanya dilakukan di dalam moov
    // dan tidak menyentuh payload mdat sama sekali.
    final moovPos = _findBox(mp4Bytes, 'moov', 0, mp4Bytes.length);
    var searchStart = 0;
    var searchEnd = mp4Bytes.length;
    if (moovPos >= 4) {
      final moovSize = _readUint32(mp4Bytes, moovPos - 4);
      if (moovSize > 8 && moovPos - 4 + moovSize <= mp4Bytes.length) {
        searchStart = moovPos - 4;
        searchEnd = moovPos - 4 + moovSize;
      }
    }

    // Ubah sample entry encv -> hvc1
    var pos = searchStart;
    while (pos < searchEnd - 4) {
      final idx = _findBox(mp4Bytes, 'encv', pos, searchEnd);
      if (idx < 0) break;
      mp4Bytes[idx] = 0x68;     // 'h'
      mp4Bytes[idx + 1] = 0x76; // 'v'
      mp4Bytes[idx + 2] = 0x63; // 'c'
      mp4Bytes[idx + 3] = 0x31; // '1'
      pos = idx + 4;
    }

    // Ubah sample entry enca -> mp4a
    pos = searchStart;
    while (pos < searchEnd - 4) {
      final idx = _findBox(mp4Bytes, 'enca', pos, searchEnd);
      if (idx < 0) break;
      mp4Bytes[idx] = 0x6d;     // 'm'
      mp4Bytes[idx + 1] = 0x70; // 'p'
      mp4Bytes[idx + 2] = 0x34; // '4'
      mp4Bytes[idx + 3] = 0x61; // 'a'
      pos = idx + 4;
    }

    // Netralkan semua box DRM CENC (sinf, senc, saio, saiz, schm, schi, tenc, pssh)
    // menjadi free box (0x66, 0x72, 0x65, 0x65) di dalam moov.
    // Ini menghilangkan 100% jejak Common Encryption di stbl/stsd sehingga ExoPlayer
    // memperlakukan video sebagai standard clear MP4 tanpa mengaktifkan DrmSessionManager.
    for (final boxType in [
      'sinf',
      'senc',
      'saio',
      'saiz',
      'schm',
      'schi',
      'tenc',
      'pssh',
    ]) {
      pos = searchStart;
      while (pos < searchEnd - 4) {
        final idx = _findBox(mp4Bytes, boxType, pos, searchEnd);
        if (idx < 0) break;
        mp4Bytes[idx] = 0x66;     // 'f'
        mp4Bytes[idx + 1] = 0x72; // 'r'
        mp4Bytes[idx + 2] = 0x65; // 'e'
        mp4Bytes[idx + 3] = 0x65; // 'e'
        pos = idx + 4;
      }
    }

    return mp4Bytes;
  }
}
