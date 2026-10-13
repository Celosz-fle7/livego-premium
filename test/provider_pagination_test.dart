import 'package:flutter_test/flutter_test.dart';
import 'package:livego_premium/models/content_item.dart';
import 'package:livego_premium/models/livego_episode.dart';
import 'package:livego_premium/services/drama_source.dart';

ContentItem _item(String id, {String platform = 'freereels'}) {
  return ContentItem(
    id: id,
    title: 'Judul $id',
    source: platform,
    category: 'Test',
    description: '',
    posterUrl: '',
    backdropUrl: '',
    rating: 0,
    episodes: 1,
    platformSlug: platform,
  );
}

/// Fake tanpa override homePage -> memakai implementasi default:
/// homeByCategory sekaligus, hasMore=false.
class _DefaultPageSource extends DramaSource {
  @override
  String get slug => 'fake';

  @override
  String get label => 'Fake';

  @override
  List<String> get categories => const ['Test'];

  @override
  Future<List<ContentItem>> homeByCategory(String category) async =>
      [_item('a'), _item('b')];

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async => const [];

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async =>
      '';
}

/// Fake dengan homePage sendiri (seperti provider asli).
class _PagedFakeSource extends _DefaultPageSource {
  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    if (page == 1) return (items: [_item('a'), _item('b')], hasMore: true);
    if (page == 2) return (items: [_item('b'), _item('c')], hasMore: false);
    return (items: const <ContentItem>[], hasMore: false);
  }
}

void main() {
  group('mergePagedItems', () {
    test('dedupe, urutan lama dipertahankan', () {
      final merged = mergePagedItems(
        [_item('a'), _item('b')],
        [_item('b'), _item('c')],
      );
      expect(merged.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('fresh kosong -> list lama', () {
      final existing = [_item('a')];
      expect(identical(mergePagedItems(existing, const []), existing), isTrue);
    });

    test('duplikat di dalam fresh dihapus', () {
      final merged = mergePagedItems(const [], [_item('a'), _item('a')]);
      expect(merged.map((e) => e.id).toList(), ['a']);
    });

    test('id sama beda platform dianggap beda item', () {
      final merged = mergePagedItems(
        [_item('a', platform: 'freereels')],
        [_item('a', platform: 'melolo')],
      );
      expect(merged.length, 2);
    });
  });

  group('DramaSource.homePage', () {
    test('default: homeByCategory sekaligus, hasMore=false', () async {
      final res = await _DefaultPageSource().homePage('Test');
      expect(res.items.map((e) => e.id).toList(), ['a', 'b']);
      expect(res.hasMore, isFalse);
    });

    test('override provider: halaman bertahap + hasMore', () async {
      final src = _PagedFakeSource();
      final p1 = await src.homePage('Test', page: 1);
      expect(p1.hasMore, isTrue);
      final p2 = await src.homePage('Test', page: 2);
      expect(p2.hasMore, isFalse);
      // UI merge: halaman 2 tidak menduplikasi 'b'.
      final merged = mergePagedItems(p1.items, p2.items);
      expect(merged.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });
  });
}
