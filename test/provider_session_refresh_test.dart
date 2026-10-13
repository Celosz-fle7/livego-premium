import 'package:flutter_test/flutter_test.dart';
import 'package:livego_premium/services/cinemaid/cinemaid_client.dart';
import 'package:livego_premium/services/drama_source.dart';
import 'package:livego_premium/services/freereels/freereels_source.dart';
import 'package:livego_premium/services/melolo/melolo_client.dart';
import 'package:livego_premium/services/melolo/melolo_source.dart';
import 'package:livego_premium/services/shorttv/shorttv_client.dart';

void main() {
  group('CinemaID deteksi error auth', () {
    test('kode auth dikenali', () {
      expect(isCinemaIdAuthCode(4001), isTrue);
      expect(isCinemaIdAuthCode('401'), isTrue);
      expect(isCinemaIdAuthCode(10001), isTrue);
      expect(isCinemaIdAuthCode(0), isFalse);
      expect(isCinemaIdAuthCode(200), isFalse);
      expect(isCinemaIdAuthCode(null), isFalse);
    });

    test('pesan auth dikenali', () {
      expect(cinemaIdMessageLooksLikeAuth('USER_NOT_LOGIN'), isTrue);
      expect(cinemaIdMessageLooksLikeAuth('token expired'), isTrue);
      expect(cinemaIdMessageLooksLikeAuth('401 Unauthorized'), isTrue);
      expect(cinemaIdMessageLooksLikeAuth('ok'), isFalse);
      expect(cinemaIdMessageLooksLikeAuth('timeout'), isFalse);
      expect(cinemaIdMessageLooksLikeAuth(''), isFalse);
    });

    test('signOut membersihkan token runtime', () async {
      final client = CinemaIdClient();
      client.setToken('token-lama');
      await client.signOut();
      expect(client.token, isNull);
    });
  });

  group('Melolo deteksi error auth', () {
    test('kode + pesan risk control dikenali', () {
      expect(meloloResponseLooksLikeAuth(code: 4001), isTrue);
      expect(meloloResponseLooksLikeAuth(code: 101000), isTrue);
      expect(
        meloloResponseLooksLikeAuth(
          code: 0,
          message: 'BOOKMALL_RISK_CONTROL_ERROR',
        ),
        isTrue,
      );
      expect(
        meloloResponseLooksLikeAuth(code: 0, message: 'USER_NOT_LOGIN'),
        isTrue,
      );
    });

    test('respons normal bukan auth', () {
      expect(meloloResponseLooksLikeAuth(code: 0, message: 'ok'), isFalse);
      expect(meloloResponseLooksLikeAuth(code: 0), isFalse);
      expect(meloloResponseLooksLikeAuth(code: null), isFalse);
    });
  });

  group('signOut per provider', () {
    test('ShortTV signOut membersihkan sesi', () {
      ShortTvClient.instance.signOut();
      expect(ShortTvClient.instance.hasSession, isFalse);
    });

    test('FreeReels + Melolo signOut no-op (tanpa sesi)', () async {
      await FreereelsSource().signOut();
      await MeloloSource().signOut();
    });

    test('signOut lewat registry (jalur yang dipakai UI)', () async {
      await DramaSourceRegistry.forSlug('cinemaid')?.signOut();
      await DramaSourceRegistry.forSlug('shorttv')?.signOut();
      await DramaSourceRegistry.forSlug('shortmax')?.signOut();
    });
  });
}
