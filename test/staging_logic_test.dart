import 'package:flutter_test/flutter_test.dart';
import 'package:livego_premium/models/livego_episode.dart';
import 'package:livego_premium/services/api/api_env.dart';
import 'package:livego_premium/services/api/dobda_endpoints.dart';

void main() {
  group('Staging Logic Tests', () {
    test('ApiEnv staging detection', () {
      // We can't easily change nobuzeroApiBaseUrl as it is a static const from String.fromEnvironment
      // But we can check its default behavior
      expect(ApiEnv.isNobuzeroStaging, isFalse);
    });

    test('DobdaEndpoints constants', () {
      expect(DobdaEndpoints.catalog, '/catalog');
      expect(DobdaEndpoints.episodes, '/episodes');
      expect(DobdaEndpoints.play, '/play');
    });

    test('LiveGoEpisode staging parsing', () {
      final json = {
        'episode_id': 'ep123',
        'serial_number': 5,
        'title': 'Test Episode'
      };
      final episode = LiveGoEpisode.fromJson(json);
      expect(episode.id, 'ep123');
      expect(episode.index, 5);
      expect(episode.title, 'Test Episode');
    });

    test('LiveGoEpisode staging parsing fallback', () {
      final json = {
        'episodeId': 'ep456',
        'serialNumber': 10,
      };
      final episode = LiveGoEpisode.fromJson(json);
      expect(episode.id, 'ep456');
      expect(episode.index, 10);
      expect(episode.title, 'Episode 10');
    });
  });
}
