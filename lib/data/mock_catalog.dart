import '../models/content_item.dart';

class MockCatalog {
  static const sources = [
    'Dramawave',
    'FreeReels',
    'Moviebox',
    'Anichin',
    'Animelovers',
    'Melolo',
    'Reelshort',
    'Mobinime',
    'Youku TV',
  ];

  static const categories = [
    'Trending',
    'New',
    'Drama',
    'Movies',
    'Anime',
    'Dubbing',
    'Perempuan',
    'Laki-Laki',
  ];

  static const hero = ContentItem(
    id: 'hero_1',
    title: 'Pemburu Iblis',
    source: 'YOUKU',
    category: 'Trending',
    description: 'Tonton sekarang dan lanjutkan judul pilihan yang lagi ramai dibuka.',
    posterUrl: 'https://picsum.photos/seed/livegohero/360/520',
    backdropUrl: 'https://picsum.photos/seed/livegobackdrop/1400/620',
    rating: 8.7,
    episodes: 47,
    updated: true,
  );

  static final items = List<ContentItem>.generate(28, (index) {
    final titles = [
      'Perfect Crown',
      'Comic 8 Revolution',
      'Bound by Promise',
      'Kabut Dalam Kegelapan',
      'Putri Kerajaan',
      'Panggilan Dari Bintang',
      'Panglima Manjakan Kekasih',
      'Case X Decoded',
      'One Piece',
      'Risky Business 2',
      'If Wishes Could Kill',
      'Istri Paruh Waktu',
      'Swapped',
      'Patah Hati Yang Kupilih',
      'On Your Lap',
      'Love And Ten Million Dollars',
      'The Drama',
      'Seriously Letting Go',
      'Yumi Cells',
      'A Splendid Match',
    ];

    final title = titles[index % titles.length];
    return ContentItem(
      id: 'item_$index',
      title: title,
      source: sources[index % sources.length],
      category: categories[index % categories.length],
      description: 'Koleksi premium LiveGO dengan tampilan cinematic, poster bersih, dan pengalaman ringan untuk mobile serta Android TV.',
      posterUrl: 'https://picsum.photos/seed/livego_poster_$index/420/620',
      backdropUrl: 'https://picsum.photos/seed/livego_back_$index/1200/520',
      rating: 6.0 + ((index % 30) / 10),
      episodes: 1 + (index % 100),
      updated: index % 3 == 0,
    );
  });

  static List<ContentItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.source.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
    }).toList();
  }
}
