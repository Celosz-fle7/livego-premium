import 'cinemaid/cinemaid_source.dart';
import 'freereels/freereels_source.dart';
import 'melolo/melolo_source.dart';
import 'moviebox/moviebox_source.dart';
import 'netshort/netshort_source.dart';
import 'shortdrama/shortdrama_source.dart';
import 'shorttv/shorttv_source.dart';

import '../models/content_item.dart';
import '../models/livego_episode.dart';

/// Kontrak satu sumber drama (satu APK).
///
/// Tiap APK yang protokolnya sudah dibedah (free-reels, drama-XX, ...)
/// implement interface ini. Home (mobile + TV) dan Player tidak perlu tahu
/// detail protokol tiap sumber — cukup panggil lewat registry.
abstract class DramaSource {
  /// Slug unik sumber, mis. 'freereels'. Dipakai sebagai `platform`.
  String get slug;

  /// Label tampil di UI.
  String get label;

  /// Daftar kategori/tab bawaan sumber (tanpa network).
  List<String> get categories;

  /// Ambil daftar konten satu kategori.
  Future<List<ContentItem>> homeByCategory(String category);

  /// Ambil daftar episode satu series.
  Future<List<LiveGoEpisode>> episodes(String seriesId);

  /// Ambil stream URL satu episode.
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  });

  /// Cari konten. Default: tidak didukung (return kosong).
  Future<List<ContentItem>> search(String query) async => const [];

  /// Keluar dari sesi provider (kalau provider punya sesi).
  /// Default: tidak ada sesi — FreeReels anonim, Melolo identitas perangkat.
  /// CinemaID & ShortTV override: buang token/sesi tersimpan, request
  /// berikutnya memakai identitas baru (auto-register / handshake ulang).
  Future<void> signOut() async {}

  /// Satu halaman konten kategori (pagination bertahap, ikut server).
  /// Default: homeByCategory sekaligus (provider lama / tanpa paginasi).
  /// [page] 1-based. [pageSize] hanya permintaan — server boleh
  /// mengembalikan jumlah berapapun; pemanggil jangan mengasumsikan
  /// pageSize. Return: (items, hasMore). hasMore=false kalau server
  /// bilang habis (halaman kosong / lebih sedikit dari yang diminta).
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final items = await homeByCategory(category);
    return (items: items, hasMore: false);
  }

  /// Info ekstra satu episode (subtitle, kualitas, status unlock).
  /// Default: tidak ada (return null).
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async =>
      null;
}

/// Gabung halaman baru ke list lama tanpa duplikat (by platformSlug:id).
/// Urutan lama dipertahankan, item baru ditambahkan di belakang.
/// Dipakai mobile + TV saat append halaman berikutnya.
List<ContentItem> mergePagedItems(
  List<ContentItem> existing,
  List<ContentItem> fresh,
) {
  if (fresh.isEmpty) return existing;
  final seen = existing.map((e) => '${e.platformSlug}:${e.id}').toSet();
  final merged = List<ContentItem>.of(existing);
  for (final item in fresh) {
    if (seen.add('${item.platformSlug}:${item.id}')) {
      merged.add(item);
    }
  }
  return merged;
}

/// Info ekstra satu episode untuk player.
class DramaEpisodeExtras {
  final List<DramaSubtitle> subtitles;
  final List<DramaQuality> qualities;
  final List<String> audioLanguages;
  final bool unlocked;
  final int episodePrice;

  const DramaEpisodeExtras({
    this.subtitles = const [],
    this.qualities = const [],
    this.audioLanguages = const [],
    this.unlocked = true,
    this.episodePrice = 0,
  });
}

class DramaSubtitle {
  final String language;
  final String displayName;
  final String url;

  const DramaSubtitle({
    required this.language,
    required this.displayName,
    required this.url,
  });
}

class DramaQuality {
  final String label;
  final String resolution;

  const DramaQuality({required this.label, required this.resolution});
}

/// Registry semua sumber drama.
///
/// Nambah APK baru:
///   1. Buat class implement DramaSource (contoh: FreereelsSource).
///   2. Daftarkan SATU baris di [_sources] bawah.
/// Tanpa ubah home mobile/TV/repository.
class DramaSourceRegistry {
  static final Map<String, DramaSource> _sources = {
    'freereels': FreereelsSource(),
    'cinemaid': CinemaIdSource(),
    'melolo': MeloloSource(),
    'shorttv': ShortTvSource(),
    'shortmax': ShortTvSource(),
    'moviebox': MovieBoxSource(),
    'netshort': NetShortSource(),
    'shortdrama': ShortDramaSource(),
  };

  static void register(DramaSource source) {
    _sources[source.slug] = source;
  }

  static bool handles(String slug) {
    final s = slug.trim().toLowerCase();
    if (s == 'shortmax') return _sources.containsKey('shorttv') || _sources.containsKey('shortmax');
    return _sources.containsKey(s);
  }

  static DramaSource? forSlug(String slug) {
    final s = slug.trim().toLowerCase();
    if (s == 'shortmax') return _sources['shorttv'] ?? _sources['shortmax'];
    return _sources[s];
  }

  static List<String> get slugs => _sources.keys.toList(growable: false);
}
