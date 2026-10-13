import 'package:flutter_test/flutter_test.dart';
import 'package:livego_premium/models/content_item.dart';
import 'package:livego_premium/models/livego_episode.dart';
import 'package:livego_premium/services/drama_source.dart';
import 'package:livego_premium/services/player/playback_resolver.dart';
import 'package:livego_premium/services/player/player_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test: ganti kualitas harus re-resolve URL per kualitas, bukan nempel `?q=`
// ke URL proxy (proxy mengabaikan query param -> kualitas tidak berubah).
//
// Fake source menggantikan 'melolo' di registry selama test, lalu
// dikembalikan ke source asli di tearDown.

class _FakeQualitySource implements DramaSource {
  final List<String?> receivedQualities = [];

  @override
  String get slug => 'melolo';

  @override
  String get label => 'FakeMelolo';

  @override
  List<String> get categories => const ['Test'];

  @override
  Future<List<ContentItem>> homeByCategory(String category) async => const [];

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async => const [
        LiveGoEpisode(id: 'ep-1', index: 1, title: 'Episode 1'),
        LiveGoEpisode(id: 'ep-2', index: 2, title: 'Episode 2'),
      ];

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    receivedQualities.add(quality);
    final q = (quality ?? 'auto').toLowerCase();
    // Tiap kualitas -> URL beda (seperti definisi video beneran).
    return 'http://127.0.0.1:9/fake_${seriesId}_${episodeId}_$q.mp4';
  }

  @override
  Future<List<ContentItem>> search(String query) async => const [];

  @override
  Future<DramaEpisodeExtras?> episodeExtras(String seriesId, String episodeId) async {
    return const DramaEpisodeExtras(
      qualities: [
        DramaQuality(label: '720p', resolution: '720x1280'),
        DramaQuality(label: '480p', resolution: '480x854'),
        DramaQuality(label: '360p', resolution: '360x640'),
      ],
    );
  }
}

void main() {
  group('PlaybackResolver quality', () {
    late DramaSource? original;
    late _FakeQualitySource fake;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'player.quality': '480p'});
      original = DramaSourceRegistry.forSlug('melolo');
      fake = _FakeQualitySource();
      DramaSourceRegistry.register(fake);
    });

    tearDown(() {
      if (original != null) DramaSourceRegistry.register(original!);
    });

    test('resolve awal memakai preferensi kualitas user', () async {
      const item = ContentItem(
        id: 'series-1',
        title: 'Test',
        source: 'fake',
        category: 'Test',
        description: '',
        posterUrl: '',
        backdropUrl: '',
        rating: 0,
        episodes: 2,
        platformSlug: 'melolo',
        chapterId: '1',
      );
      final source = await PlaybackResolver.resolve(item);
      expect(fake.receivedQualities, ['480p']);
      expect(source.toStreamInfo().url, contains('_480p'));
      expect(source.toStreamInfo().episodeId, 'ep-1');
    });

    test('URL kualitas tidak mengandung fabrikasi ?q=', () async {
      const item = ContentItem(
        id: 'series-1',
        title: 'Test',
        source: 'fake',
        category: 'Test',
        description: '',
        posterUrl: '',
        backdropUrl: '',
        rating: 0,
        episodes: 2,
        platformSlug: 'melolo',
        chapterId: '1',
      );
      final info = await PlaybackResolver.resolveStreamInfo(item);
      expect(info.qualities.length, 3);
      for (final q in info.qualities) {
        expect(q.url, isNot(contains('?q=')));
        expect(q.url, isNot(contains('&q=')));
      }
      // Semua entri kualitas menunjuk URL dasar yang sama (re-resolve
      // per kualitas dilakukan via streamUrlForQuality).
      expect(info.qualities.map((q) => q.url).toSet().length, 1);
    });

    test('streamUrlForQuality re-resolve dengan kualitas yang dipilih', () async {
      const item = ContentItem(
        id: 'series-1',
        title: 'Test',
        source: 'fake',
        category: 'Test',
        description: '',
        posterUrl: '',
        backdropUrl: '',
        rating: 0,
        episodes: 2,
        platformSlug: 'melolo',
        chapterId: '1',
      );
      final url720 = await PlaybackResolver.streamUrlForQuality(
        item,
        episodeId: 'ep-1',
        quality: '720p',
      );
      expect(url720, contains('_720p'));
      expect(fake.receivedQualities.last, '720p');

      final url360 = await PlaybackResolver.streamUrlForQuality(
        item,
        episodeId: 'ep-1',
        quality: '360p',
      );
      expect(url360, contains('_360p'));
      expect(url360, isNot(equals(url720)));
    });
  });

  // PlayerPreferences.load() membaca mock di atas; reset flag antar test
  // tidak diperlukan karena setiap test set mock baru + load() sekali jalan.
  // (PlayerPreferences._loaded statis; setUpAll di bawah memaksa reload.)
  setUpAll(() {
    // Pastikan PlayerPreferences.quality ikut mock ('480p'), bukan sisa test lain.
    PlayerPreferences.quality = '480p';
  });
}
