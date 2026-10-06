import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'freereels_config.dart';

/// Signing meniru HeaderInterceptor APK (dramawave/core/network/interceptor).
///
/// Skema (terverifikasi dari bytecode + live test):
///   signature = MD5_HEX( salt + '&' + authSecret )
///   Authorization: oauth_signature=<sig>,oauth_token=<key>,ts=<millis>
class FreereelsAuth {
  static String buildAuthorization({
    required String authKey,
    required String authSecret,
  }) {
    final raw = '${FreereelsConfig.salt}&$authSecret';
    final signature = md5.convert(utf8.encode(raw)).toString();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'oauth_signature=$signature,oauth_token=$authKey,ts=$ts';
  }
}
