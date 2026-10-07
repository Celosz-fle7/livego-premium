import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Mesin Dekripsi & Otentikasi CinemaID (com.movieph.bj.playvibes V5.0.7).
///
/// Direkayasa balik dari DEX:
/// - Request Sign: MD5(SALT + device_id + cur_time).toUpperCase()
/// - Response Decryptor: AES-128-CBC (PKCS5Padding/PKCS7Padding)
///   Key: '0123456789123456'
///   IV:  '2015030120123456'
///   Class: Lak/a (AESOperator) dipanggil oleh Lxj/c (LoggingInterceptor)
class CinemaIdCrypto {
  CinemaIdCrypto._();

  static const String salt = '47Q8tBqO4YqrMHf4';
  static const String aesKeyStr = '0123456789123456';
  static const String aesIvStr = '2015030120123456';
  static const String badciHeader = '62873ffa217d4a0d4b6d326b10e2d48d';

  /// Menghitung header 'sign' untuk otentikasi request ke server backend.
  static String generateSign(String deviceId, String curTime) {
    final payload = utf8.encode('$salt$deviceId$curTime');
    return md5.convert(payload).toString().toUpperCase();
  }

  /// Membuat header standar OkHttp yang lolos proteksi WAF CloudFront.
  static Map<String, String> buildHeaders({
    required String deviceId,
    required String curTime,
    String token = '',
    String channelCode = 'official',
    String version = '40000',
  }) {
    final sign = generateSign(deviceId, curTime);
    return {
      'app_id': 'movieph',
      'package_name': 'com.movieph.bj.playvibes',
      'version': version,
      'version_name': 'V5.0.7',
      'platform': 'android',
      'os': 'android',
      'sys_platform': '2',
      'device_id': deviceId,
      'channel_code': channelCode,
      'androidid': deviceId,
      'cur_time': curTime,
      'token': token,
      'sign': sign,
      'Badci': badciHeader,
      'User-Agent': 'okhttp/4.9.3',
      'Content-Type': 'application/x-www-form-urlencoded',
    };
  }

  /// Mendekripsi respons ciphertext SHOK... atau payload JSON terenkripsi.
  /// Menggunakan AES-128-CBC standar murni Dart tanpa dependensi eksternal.
  static dynamic decryptResponse(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};

    // Jika sudah berupa plaintext JSON
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(trimmed);
      } catch (_) {}
    }

    // Eksekusi pipeline dekripsi Lak/a
    try {
      // 1. Ekstrak payload (potong prefix SHOK jika ada)
      String payload = trimmed;
      if (payload.startsWith('SHOK')) {
        payload = payload.substring(4);
      }

      // 2. Decode bytes (Base64 atau Hex)
      Uint8List? cipherBytes;
      try {
        var b64 = payload;
        final rem = b64.length % 4;
        if (rem != 0) b64 += '=' * (4 - rem);
        cipherBytes = base64.decode(b64);
      } catch (_) {
        cipherBytes = _hexDecode(payload);
      }

      if (cipherBytes != null && cipherBytes.isNotEmpty) {
        final keyBytes = Uint8List.fromList(utf8.encode(aesKeyStr));
        final ivBytes = Uint8List.fromList(utf8.encode(aesIvStr));
        final decryptedBytes = _aesCbcDecrypt(cipherBytes, keyBytes, ivBytes);
        final decryptedText = utf8.decode(decryptedBytes, allowMalformed: true).trim();

        if (decryptedText.startsWith('{') || decryptedText.startsWith('[')) {
          return jsonDecode(decryptedText);
        }
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  static Uint8List? _hexDecode(String hex) {
    try {
      final clean = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
      if (clean.length % 2 != 0) return null;
      final result = Uint8List(clean.length ~/ 2);
      for (var i = 0; i < clean.length; i += 2) {
        result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  // --- Implementasi Ringkas AES-128 CBC Decryptor Murni Dart ---

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

  static late final List<int> _invSBox = () {
    final list = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      list[_sBox[i]] = i;
    }
    return list;
  }();

  static const List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  static int _mul(int a, int b) {
    var p = 0;
    for (var i = 0; i < 8; i++) {
      if ((b & 1) != 0) p ^= a;
      final hi = (a & 0x80) != 0;
      a = (a << 1) & 0xff;
      if (hi) a ^= 0x1b;
      b >>= 1;
    }
    return p;
  }

  static List<Uint8List> _keyExpansion(Uint8List key) {
    final w = <Uint8List>[];
    for (var i = 0; i < 4; i++) {
      w.add(Uint8List.fromList(key.sublist(4 * i, 4 * (i + 1))));
    }
    for (var i = 4; i < 44; i++) {
      var temp = Uint8List.fromList(w[i - 1]);
      if (i % 4 == 0) {
        final rot = Uint8List.fromList([temp[1], temp[2], temp[3], temp[0]]);
        final sub = Uint8List.fromList([
          _sBox[rot[0]] ^ _rcon[i ~/ 4],
          _sBox[rot[1]],
          _sBox[rot[2]],
          _sBox[rot[3]],
        ]);
        temp = sub;
      }
      final wi = Uint8List(4);
      for (var j = 0; j < 4; j++) {
        wi[j] = w[i - 4][j] ^ temp[j];
      }
      w.add(wi);
    }
    return w;
  }

  static Uint8List _decryptBlock(Uint8List block, List<Uint8List> w) {
    final s = List.generate(4, (r) => List.generate(4, (c) => block[r + 4 * c]));

    // Round 10 AddRoundKey
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        s[r][c] ^= w[40 + c][r];
      }
    }

    for (var round = 9; round >= 1; round--) {
      // InvShiftRows
      final temp1 = s[1][3];
      s[1][3] = s[1][2]; s[1][2] = s[1][1]; s[1][1] = s[1][0]; s[1][0] = temp1;
      final t20 = s[2][0]; final t21 = s[2][1];
      s[2][0] = s[2][2]; s[2][1] = s[2][3]; s[2][2] = t20; s[2][3] = t21;
      final temp3 = s[3][0];
      s[3][0] = s[3][1]; s[3][1] = s[3][2]; s[3][2] = s[3][3]; s[3][3] = temp3;

      // InvSubBytes
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          s[r][c] = _invSBox[s[r][c]];
        }
      }

      // AddRoundKey
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          s[r][c] ^= w[round * 4 + c][r];
        }
      }

      // InvMixColumns
      for (var c = 0; c < 4; c++) {
        final u0 = s[0][c]; final u1 = s[1][c]; final u2 = s[2][c]; final u3 = s[3][c];
        s[0][c] = _mul(u0, 0x0e) ^ _mul(u1, 0x0b) ^ _mul(u2, 0x0d) ^ _mul(u3, 0x09);
        s[1][c] = _mul(u0, 0x09) ^ _mul(u1, 0x0e) ^ _mul(u2, 0x0b) ^ _mul(u3, 0x0d);
        s[2][c] = _mul(u0, 0x0d) ^ _mul(u1, 0x09) ^ _mul(u2, 0x0e) ^ _mul(u3, 0x0b);
        s[3][c] = _mul(u0, 0x0b) ^ _mul(u1, 0x0d) ^ _mul(u2, 0x09) ^ _mul(u3, 0x0e);
      }
    }

    // Round 0
    final temp1 = s[1][3];
    s[1][3] = s[1][2]; s[1][2] = s[1][1]; s[1][1] = s[1][0]; s[1][0] = temp1;
    final t20 = s[2][0]; final t21 = s[2][1];
    s[2][0] = s[2][2]; s[2][1] = s[2][3]; s[2][2] = t20; s[2][3] = t21;
    final temp3 = s[3][0];
    s[3][0] = s[3][1]; s[3][1] = s[3][2]; s[3][2] = s[3][3]; s[3][3] = temp3;

    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        s[r][c] = _invSBox[s[r][c]] ^ w[c][r];
      }
    }

    final out = Uint8List(16);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        out[r + 4 * c] = s[r][c];
      }
    }
    return out;
  }

  static Uint8List _aesCbcDecrypt(Uint8List cipherText, Uint8List key, Uint8List iv) {
    if (cipherText.isEmpty || cipherText.length % 16 != 0) return cipherText;
    final w = _keyExpansion(key);
    final output = <int>[];
    var prev = Uint8List.fromList(iv);

    for (var i = 0; i < cipherText.length; i += 16) {
      final block = Uint8List.fromList(cipherText.sublist(i, i + 16));
      final dec = _decryptBlock(block, w);
      for (var j = 0; j < 16; j++) {
        output.add(dec[j] ^ prev[j]);
      }
      prev = block;
    }

    // PKCS5 unpadding
    if (output.isNotEmpty) {
      final padLen = output.last;
      if (padLen >= 1 && padLen <= 16) {
        var valid = true;
        for (var i = output.length - padLen; i < output.length; i++) {
          if (output[i] != padLen) { valid = false; break; }
        }
        if (valid) {
          return Uint8List.fromList(output.sublist(0, output.length - padLen));
        }
      }
    }
    return Uint8List.fromList(output);
  }
}
