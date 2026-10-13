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
  final String _slug;

  _FakeQualitySource(this._slug);

  @override
  String get slug => _slug;

  @override
  String get label => 'Fake$_slug';

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
  Future<void> signOut() async {}

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
    late DramaSource? originalMelolo;
    late DramaSource? originalShortTv;
    late _FakeQualitySource fakeMelolo;
    late _FakeQualitySource fakeShortTv;

    ContentItem itemFor(String slug, {String chapterId = '1'}) => ContentItem(
          id: 'series-1',
          title: 'Test',
          source: 'fake',
          category: 'Test',
          description: '',
          posterUrl: '',
          backdropUrl: '',
          rating: 0,
          episodes: 2,
          platformSlug: slug,
          chapterId: chapterId,
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({'player.quality': '480p'});
      PlayerPreferences.quality = '480p';
      PlayerPreferences.subtitleEnabled = true;
      PlayerPreferences.subtitleLanguage = 'Auto';
      // Normalisasi state per-provider: tiap test mulai dari nol,
      // tidak bergantung urutan eksekusi.
      await PlayerPreferences.setQualityFor('melolo', '480p');
      await PlayerPreferences.setQualityFor('shorttv', '480p');
      await PlayerPreferences.setSubtitleFor('melolo', enabled: true, language: 'Auto');
      await PlayerPreferences.setSubtitleFor('shorttv', enabled: true, language: 'Auto');
      originalMelolo = DramaSourceRegistry.forSlug('melolo');
      originalShortTv = DramaSourceRegistry.forSlug('shorttv');
      fakeMelolo = _FakeQualitySource('melolo');
      fakeShortTv = _FakeQualitySource('shorttv');
      DramaSourceRegistry.register(fakeMelolo);
      DramaSourceRegistry.register(fakeShortTv);
    });

    tearDown(() {
      if (originalMelolo != null) DramaSourceRegistry.register(originalMelolo!);
      if (originalShortTv != null) DramaSourceRegistry.register(originalShortTv!);
    });

    test('resolve awal memakai preferensi kualitas user', () async {
      final source = await PlaybackResolver.resolve(itemFor('melolo'));
      expect(fakeMelolo.receivedQualities, ['480p']);
      expect(source.toStreamInfo().url, contains('_480p'));
      expect(source.toStreamInfo().episodeId, 'ep-1');
    });

    test('URL kualitas tidak mengandung fabrikasi ?q=', () async {
      final info = await PlaybackResolver.resolveStreamInfo(itemFor('melolo'));
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
      final url720 = await PlaybackResolver.streamUrlForQuality(
        itemFor('melolo'),
        episodeId: 'ep-1',
        quality: '720p',
      );
      expect(url720, contains('_720p'));
      expect(fakeMelolo.receivedQualities.last, '720p');

      final url360 = await PlaybackResolver.streamUrlForQuality(
        itemFor('melolo'),
        episodeId: 'ep-1',
        quality: '360p',
      );
      expect(url360, contains('_360p'));
      expect(url360, isNot(equals(url720)));
    });

    test('setingan kualitas per provider saling terisolasi', () async {
      await PlayerPreferences.setQualityFor('melolo', '720p');
      await PlayerPreferences.setQualityFor('shorttv', '360p');

      await PlaybackResolver.resolve(itemFor('melolo'));
      expect(fakeMelolo.receivedQualities.last, '720p');

      await PlaybackResolver.resolve(itemFor('shorttv'));
      expect(fakeShortTv.receivedQualities.last, '360p');

      // Provider yang belum diatur -> fallback kualitas global (480p).
      expect(PlayerPreferences.qualityFor('freereels'), '480p');
      expect(PlayerPreferences.qualityFor('melolo'), '720p');
      expect(PlayerPreferences.qualityFor('shorttv'), '360p');
    });

    test('setingan subtitle per provider saling terisolasi', () async {
      await PlayerPreferences.setSubtitleFor('melolo', enabled: false, language: 'OFF');
      await PlayerPreferences.setSubtitleFor('shorttv', enabled: true, language: 'en');

      final melolo = await PlaybackResolver.resolve(itemFor('melolo'));
      expect(melolo.selectedSubtitle, 'OFF');

      final shorttv = await PlaybackResolver.resolve(itemFor('shorttv'));
      expect(shorttv.selectedSubtitle, 'en');

      // Provider belum diatur -> fallback global (enabled=true, Auto).
      expect(PlayerPreferences.subtitleEnabledFor('freereels'), isTrue);
    });
  });

  // PlayerPreferences.load() membaca mock di atas; nilai global di-set
  // langsung per test agar tidak bergantung urutan test.
  setUpAll(() {
    PlayerPreferences.quality = '480p';
  });
}
