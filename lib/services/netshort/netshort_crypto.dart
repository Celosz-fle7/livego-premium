import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Utilitas Kriptografi NetShort (AES-256-ECB & RSA-2048 PKCS1 v1.5).
/// Berjalan murni di Dart tanpa dependensi eksternal C/native.
class NetShortCrypto {
  /// Modulus N RSA Public Key resmi NetShort (2048-bit)
  /// Didapat dari interceptor wrc.java
  static final BigInt _rsaPubModN = BigInt.parse(
    'da9a1732cb59f0d09613bf75e4c5f30d60b9fedfa8076c1a19fb243ea499c0bab1778641'
    '4741f571bd6d019459715ecff8b98e77a49837186710b696b8a4c3f83df1933f13b752f9'
    '8ffca71aa56dd4c0db890204cd740a524343487e93d00f97ce8ffaefff103905e55497d6'
    'd3aadeb1b69e36f89b7f1e9073bf23f7a6c220f9713ebb627a29554c11d414e5e38abc4a'
    'fe48bf98ef0fdac9916e9b7bddfb1059d1a64c631f606bdf3c0a46cb16f12e42ffaab063'
    '536e57a4cf1ad0c06acc559401c8479aa48127a31b7da9b549281fddbd94dbcb3aee7396'
    'f8988eae177a8952dcb0b1715c0e781d7f996de8f701b381ea329a126a7f6f3d5a9a7784'
    'd4d617c3',
    radix: 16,
  );

  /// Public Exponent e (65537)
  static final BigInt _rsaExpE = BigInt.from(65537);

  /// Modulus N RSA Private Key resmi NetShort (2048-bit)
  /// Didapat dari DecryptInterceptor tr2.java
  static final BigInt _rsaPrivModN = BigInt.parse(
    '8ad13975a5dedb8d3454f776d6a075b584b0838f6fbd6e0d4c818f23e42ef15dac3a6c97'
    'd3a178566c7d5f5cd6e714556ac7260d12b72e394c09671c8381cc545cce325a746c79bd'
    '8617dec63a270043691e0f35589b0932e25ad2470bdc5eeb4944b3d409140d7dceaea5f9'
    '361b94ca87afc270fe135757974c5efebdd130d921f100e21329b49f71a657aff855b3a6'
    'b56911ec045fbb446f7d79bc1920febf020232a97f516c354dea2c62d6fd86dff6f00142'
    'c72d2a867526aa8a3fdc6b5edf6c51884da782784699e9dfcfe19b8e2be3c43dd6cf42de'
    '926d8e2565a63046f76ba47ef792280f213803cc80ce345c9b2759bbc112a5ab5c31587c'
    '1b8a6a6d',
    radix: 16,
  );

  /// Private Exponent d resmi NetShort (2048-bit)
  static final BigInt _rsaPrivExpD = BigInt.parse(
    '3f3ddc6095c5b6de58a610eb6a12462e011a6d854e51cdae6f5962fde5f9e0ea5d096ce9'
    'aa77989c3ee6cb283f9b9ceee12b835157626ec399b97ae9499c3b9b7f804cfe5aa604bc'
    '6c37b9bd33470b5eaaa81023ac8f4d1c8a74f7f1781cd87d76aebf026d745e451f80ff8a'
    '4eb5380f20cbd8d8a357ea65b43f0dd41e640c4d6282891572c6af867bb620da0c457604'
    'efc5aaeaeacd102b855b0f6195dbfcd4cf66db0e7ab75090394ba4a68e267e62e36517b6'
    'b3e930b5c05579f1873fc0a3d0e787d9d1a5b6397661240c441154095a22c58a4eadc8c8'
    '1e8ab35ab8bc21f519dad5be9d4bc7979219f5157179f9c568b1a7c625dddac93a4a7e1a'
    '0ff97d61',
    radix: 16,
  );

  /// Buat random 32-karakter lowercase alphanumeric AES key (sama seperti cfh.H() di APK NetShort)
  static String generateAesKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = math.Random();
    final buffer = StringBuffer();
    for (int i = 0; i < 32; i++) {
      buffer.write(chars[rnd.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  /// Enkripsi RSA PKCS#1 v1.5 dengan Public Key resmi NetShort (2048-bit / 256 bytes)
  static String rsaEncrypt(Uint8List dataBytes) {
    const k = 256;
    final buffer = Uint8List(k);
    buffer[0] = 0x00;
    buffer[1] = 0x02; // Type 2 encryption block
    final psLen = k - 3 - dataBytes.length;
    final rnd = math.Random();
    for (int i = 0; i < psLen; i++) {
      int b = rnd.nextInt(255) + 1; // Non-zero random padding bytes
      buffer[2 + i] = b;
    }
    buffer[2 + psLen] = 0x00;
    buffer.setRange(3 + psLen, k, dataBytes);

    BigInt m = BigInt.zero;
    for (int i = 0; i < k; i++) {
      m = (m << 8) | BigInt.from(buffer[i]);
    }

    final c = m.modPow(_rsaExpE, _rsaPubModN);

    final out = Uint8List(k);
    var temp = c;
    for (int i = k - 1; i >= 0; i--) {
      out[i] = (temp & BigInt.from(0xff)).toInt();
      temp >>= 8;
    }
    return base64.encode(out);
  }

  /// Dekripsi RSA PKCS#1 v1.5 dengan Private Key resmi NetShort (2048-bit / 256 bytes)
  static Uint8List rsaDecrypt(Uint8List cipherBytes) {
    const k = 256;
    BigInt c = BigInt.zero;
    for (int i = 0; i < cipherBytes.length; i++) {
      c = (c << 8) | BigInt.from(cipherBytes[i]);
    }

    final m = c.modPow(_rsaPrivExpD, _rsaPrivModN);

    final eb = Uint8List(k);
    var temp = m;
    for (int i = k - 1; i >= 0; i--) {
      eb[i] = (temp & BigInt.from(0xff)).toInt();
      temp >>= 8;
    }

    // PKCS#1 v1.5 unpad: 00 02 PS 00 <data>
    int sepIdx = -1;
    for (int i = 2; i < k; i++) {
      if (eb[i] == 0x00) {
        sepIdx = i;
        break;
      }
    }
    if (sepIdx == -1) {
      throw const FormatException('Invalid PKCS#1 v1.5 padding');
    }
    return eb.sublist(sepIdx + 1);
  }

  /// Enkripsi AES-256-ECB dengan PKCS7 padding
  static String aes256EcbEncrypt(String plainText, String key) {
    final keyBytes = utf8.encode(key);
    final ptBytes = utf8.encode(plainText);
    final padLen = 16 - (ptBytes.length % 16);
    final padded = Uint8List(ptBytes.length + padLen);
    padded.setRange(0, ptBytes.length, ptBytes);
    for (int i = ptBytes.length; i < padded.length; i++) {
      padded[i] = padLen;
    }

    final cipher = _Aes256Core(Uint8List.fromList(keyBytes));
    final ct = Uint8List(padded.length);
    for (int i = 0; i < padded.length; i += 16) {
      final block = padded.sublist(i, i + 16);
      final encBlock = cipher.encryptBlock(block);
      ct.setRange(i, i + 16, encBlock);
    }
    return base64.encode(ct);
  }

  /// Dekripsi AES-256-ECB dengan PKCS7 unpadding
  static String aes256EcbDecrypt(String base64CipherText, Uint8List rawKeyBytes) {
    final ctBytes = base64.decode(base64CipherText);
    final cipher = _Aes256Core(rawKeyBytes);
    final pt = Uint8List(ctBytes.length);
    for (int i = 0; i < ctBytes.length; i += 16) {
      final block = ctBytes.sublist(i, i + 16);
      final decBlock = cipher.decryptBlock(block);
      pt.setRange(i, i + 16, decBlock);
    }

    if (pt.isEmpty) return '';
    final padLen = pt.last;
    final unpaddedLen = (padLen > 0 && padLen <= 16) ? pt.length - padLen : pt.length;
    return utf8.decode(pt.sublist(0, unpaddedLen.clamp(0, pt.length)), allowMalformed: true);
  }

  static const MethodChannel _nativeChannel = MethodChannel('livego/netshort_crypto');

  /// Native Android hardware-accelerated RSA Decryption
  static Future<Uint8List> nativeRsaDecrypt(Uint8List cipherBytes) async {
    try {
      final res = await _nativeChannel.invokeMethod<Uint8List>('rsaDecrypt', {
        'cipherBytes': cipherBytes,
      });
      if (res != null && res.isNotEmpty) return res;
    } catch (_) {}
    return rsaDecrypt(cipherBytes);
  }

  /// Native Android hardware-accelerated AES-256-ECB Decryption
  static Future<String> nativeAesDecrypt(String cipherText, Uint8List rawKeyBytes) async {
    try {
      final res = await _nativeChannel.invokeMethod<String>('aesDecrypt', {
        'cipherText': cipherText,
        'key': rawKeyBytes,
      });
      if (res != null && res.isNotEmpty) return res;
    } catch (_) {}
    return aes256EcbDecrypt(cipherText, rawKeyBytes);
  }
}

/// Implementasi AES-256 block encryptor & decryptor (14 rounds, Nk=8, Nr=14)
class _Aes256Core {
  late final List<int> _rk;

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

  static const List<int> _invSBox = [
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d
  ];

  static const List<int> _rCon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  _Aes256Core(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 key must be 32 bytes, got ${key.length}');
    }
    _keyExpansion(key);
  }

  void _keyExpansion(Uint8List key) {
    // 60 words for AES-256 (4 * (14 + 1))
    _rk = List<int>.filled(60, 0);
    for (int i = 0; i < 8; i++) {
      _rk[i] = (key[4 * i] << 24) | (key[4 * i + 1] << 16) | (key[4 * i + 2] << 8) | key[4 * i + 3];
    }
    for (int i = 8; i < 60; i++) {
      int temp = _rk[i - 1];
      if (i % 8 == 0) {
        temp = ((temp << 8) | ((temp >> 24) & 0xff)) & 0xffffffff;
        temp = (_sBox[(temp >> 24) & 0xff] << 24) |
            (_sBox[(temp >> 16) & 0xff] << 16) |
            (_sBox[(temp >> 8) & 0xff] << 8) |
            _sBox[temp & 0xff];
        temp ^= (_rCon[i ~/ 8] << 24);
      } else if (i % 8 == 4) {
        temp = (_sBox[(temp >> 24) & 0xff] << 24) |
            (_sBox[(temp >> 16) & 0xff] << 16) |
            (_sBox[(temp >> 8) & 0xff] << 8) |
            _sBox[temp & 0xff];
      }
      _rk[i] = (_rk[i - 8] ^ temp) & 0xffffffff;
    }
  }

  Uint8List encryptBlock(Uint8List input) {
    final state = List<int>.generate(16, (i) => input[i]);
    _addRoundKey(state, 0);
    for (int round = 1; round < 14; round++) {
      _subBytes(state);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, round);
    }
    _subBytes(state);
    _shiftRows(state);
    _addRoundKey(state, 14);
    return Uint8List.fromList(state);
  }

  Uint8List decryptBlock(Uint8List input) {
    final state = List<int>.generate(16, (i) => input[i]);
    _addRoundKey(state, 14);
    for (int round = 13; round >= 1; round--) {
      _invShiftRows(state);
      _invSubBytes(state);
      _addRoundKey(state, round);
      _invMixColumns(state);
    }
    _invShiftRows(state);
    _invSubBytes(state);
    _addRoundKey(state, 0);
    return Uint8List.fromList(state);
  }

  void _addRoundKey(List<int> state, int round) {
    for (int i = 0; i < 4; i++) {
      final w = _rk[round * 4 + i];
      state[4 * i] ^= (w >> 24) & 0xff;
      state[4 * i + 1] ^= (w >> 16) & 0xff;
      state[4 * i + 2] ^= (w >> 8) & 0xff;
      state[4 * i + 3] ^= w & 0xff;
    }
  }

  void _subBytes(List<int> state) {
    for (int i = 0; i < 16; i++) {
      state[i] = _sBox[state[i]];
    }
  }

  void _shiftRows(List<int> state) {
    // Row 1: shift left 1
    int temp = state[1];
    state[1] = state[5];
    state[5] = state[9];
    state[9] = state[13];
    state[13] = temp;
    // Row 2: shift left 2
    temp = state[2];
    state[2] = state[10];
    state[10] = temp;
    temp = state[6];
    state[6] = state[14];
    state[14] = temp;
    // Row 3: shift left 3
    temp = state[3];
    state[3] = state[15];
    state[15] = state[11];
    state[11] = state[7];
    state[7] = temp;
  }

  void _invSubBytes(List<int> state) {
    for (int i = 0; i < 16; i++) {
      state[i] = _invSBox[state[i]];
    }
  }

  void _invShiftRows(List<int> state) {
    // Row 1: shift right 1
    int temp = state[13];
    state[13] = state[9];
    state[9] = state[5];
    state[5] = state[1];
    state[1] = temp;
    // Row 2: shift right 2
    temp = state[2];
    state[2] = state[10];
    state[10] = temp;
    temp = state[6];
    state[6] = state[14];
    state[14] = temp;
    // Row 3: shift right 3
    temp = state[3];
    state[3] = state[7];
    state[7] = state[11];
    state[11] = state[15];
    state[15] = temp;
  }

  static int _gMul(int a, int b) {
    int p = 0;
    for (int i = 0; i < 8; i++) {
      if ((b & 1) != 0) p ^= a;
      final hi = a & 0x80;
      a = (a << 1) & 0xff;
      if (hi != 0) a ^= 0x1b;
      b >>= 1;
    }
    return p;
  }

  void _mixColumns(List<int> state) {
    for (int c = 0; c < 4; c++) {
      final i = 4 * c;
      final s0 = state[i];
      final s1 = state[i + 1];
      final s2 = state[i + 2];
      final s3 = state[i + 3];

      state[i] = _gMul(s0, 0x02) ^ _gMul(s1, 0x03) ^ s2 ^ s3;
      state[i + 1] = s0 ^ _gMul(s1, 0x02) ^ _gMul(s2, 0x03) ^ s3;
      state[i + 2] = s0 ^ s1 ^ _gMul(s2, 0x02) ^ _gMul(s3, 0x03);
      state[i + 3] = _gMul(s0, 0x03) ^ s1 ^ s2 ^ _gMul(s3, 0x02);
    }
  }

  void _invMixColumns(List<int> state) {
    for (int c = 0; c < 4; c++) {
      final i = 4 * c;
      final s0 = state[i];
      final s1 = state[i + 1];
      final s2 = state[i + 2];
      final s3 = state[i + 3];

      state[i] = _gMul(s0, 0x0e) ^ _gMul(s1, 0x0b) ^ _gMul(s2, 0x0d) ^ _gMul(s3, 0x09);
      state[i + 1] = _gMul(s0, 0x09) ^ _gMul(s1, 0x0e) ^ _gMul(s2, 0x0b) ^ _gMul(s3, 0x0d);
      state[i + 2] = _gMul(s0, 0x0d) ^ _gMul(s1, 0x09) ^ _gMul(s2, 0x0e) ^ _gMul(s3, 0x0b);
      state[i + 3] = _gMul(s0, 0x0b) ^ _gMul(s1, 0x0d) ^ _gMul(s2, 0x09) ^ _gMul(s3, 0x0e);
    }
  }
}
