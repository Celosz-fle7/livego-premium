import 'freereels/freereels_source.dart';

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
  });

  /// Cari konten. Default: tidak didukung (return kosong).
  Future<List<ContentItem>> search(String query) async => const [];

  /// Info ekstra satu episode (subtitle, kualitas, status unlock).
  /// Default: tidak ada (return null).
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async =>
      null;
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
  };

  static void register(DramaSource source) {
    _sources[source.slug] = source;
  }

  static bool handles(String slug) => _sources.containsKey(slug);

  static DramaSource? forSlug(String slug) => _sources[slug];

  static List<String> get slugs => _sources.keys.toList(growable: false);
}
