import 'package:flutter_test/flutter_test.dart';
import 'package:livego_premium/services/cinemaid/cinemaid_client.dart';
import 'package:livego_premium/services/cinemaid/cinemaid_config.dart';

void main() {
  group('CinemaID Tests', () {
    test('Config parameters validation', () {
      expect(CinemaIdConfig.baseUrl, 'https://freecinenewph.t62nds.com');
      expect(CinemaIdConfig.cdnBaseUrl, 'http://movieph.xrrqe.com');
      expect(CinemaIdConfig.secretToken, 'gcAIKnfz');
    });

    test('Client instance initializes cleanly', () {
      final client = CinemaIdClient();
      expect(client, isNotNull);
    });
  });
}
