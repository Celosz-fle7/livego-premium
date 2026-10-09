import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'freereels_client.dart';
import 'freereels_config.dart';

/// Adapter FreeReels sebagai DramaSource.
///
/// Meniru 100% perilaku APK: kategori = tab bawaan APK,
/// home = GET /frv2-api/homepage/v2/tab/index per tab_key.
class FreereelsSource implements DramaSource {
  final FreereelsClient _client = FreereelsClient();

  /// Cache episodeId -> stream m3u8, diisi saat episodes() dipanggil.
  /// Format key: "$seriesId:$episodeId".
  final Map<String, String> _streamCache = {};

  /// Cache data episode mentah untuk extras (subtitle, kualitas, unlock).
  /// Format key: "$seriesId:$episodeId".
  final Map<String, Map<String, dynamic>> _episodeCache = {};

  @override
  String get slug => 'freereels';

  @override
  String get label => 'FreeReels';

  @override
  List<String> get categories => FreereelsConfig.tabKeys.keys.toList(growable: false);

  @override
  Future<List<ContentItem>> homeByCategory(String category) {
    final tabKey =
        FreereelsConfig.tabKeys[category] ?? FreereelsConfig.tabKeys['Popular']!;
    // Ambil semua halaman (paginasi) agar konten ratusan, bukan cuma 10.
    return _client.allSeriesFromTab(tabKey: tabKey, category: category);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    final raw = await _client.episodeList(seriesId);
    final out = <LiveGoEpisode>[];
    for (final e in raw) {
      final id = '${e['id'] ?? ''}';
      if (id.isEmpty) continue;
      final url = _pickStreamUrl(e);
      if (url.isNotEmpty) _streamCache['$seriesId:$id'] = url;
      _episodeCache['$seriesId:$id'] = e;
      out.add(LiveGoEpisode(
        id: id,
        index: int.tryParse('${e['index'] ?? 0}') ?? 0,
        title: '${e['name'] ?? 'Episode ${e['index'] ?? ''}'}',
      ));
    }
    return out;
  }

  @override
  Future<String> streamUrl({required String seriesId, required String episodeId}) async {
    final cached = _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) return cached;

    // Belum di-cache: ambil ulang episode list lalu cari episode-nya.
    final raw = await _client.episodeList(seriesId);
    for (final e in raw) {
      if ('${e['id'] ?? ''}' == episodeId) {
        final url = _pickStreamUrl(e);
        if (url.isNotEmpty) {
          _streamCache['$seriesId:$episodeId'] = url;
          return url;
        }
      }
    }
    throw Exception('FreeReels: stream URL tidak ditemukan ($seriesId/$episodeId)');
  }

  /// Pilih URL stream terbaik dari item episode.
  /// Verified: external_audio_h264_m3u8 -> 200 audio/x-mpegurl (master playlist).
  String _pickStreamUrl(Map<String, dynamic> e) {
    for (final k in ['external_audio_h264_m3u8', 'm3u8_url', 'external_audio_h265_m3u8']) {
      final v = '${e[k] ?? ''}';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) {
    return _client.search(query);
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    var raw = _episodeCache['$seriesId:$episodeId'];
    if (raw == null) {
      // Belum di-cache: ambil episode list dulu.
      await episodes(seriesId);
      raw = _episodeCache['$seriesId:$episodeId'];
    }
    if (raw == null) return null;

    final subtitles = <DramaSubtitle>[];
    final subList = raw['subtitle_list'] as List? ?? const [];
    for (final s in subList) {
      final m = s as Map;
      final url = '${m['vtt'] ?? m['subtitle'] ?? ''}';
      if (url.isEmpty) continue;
      subtitles.add(DramaSubtitle(
        language: '${m['language'] ?? ''}',
        displayName: '${m['display_name'] ?? m['language'] ?? ''}',
        url: url,
      ));
    }

    final qualities = <DramaQuality>[];
    final res = '${raw['trans_resolution'] ?? ''}';
    for (final r in res.split(',')) {
      final t = r.trim();
      if (t.isEmpty) continue;
      final h = t.split('x');
      final label = h.length == 2 ? '${h[1]}p' : t;
      qualities.add(DramaQuality(label: label, resolution: t));
    }

    final audioLangs = <String>[];
    final audio = raw['audio'] as List?;
    if (audio != null) {
      for (final a in audio) {
        audioLangs.add('$a');
      }
    }

    return DramaEpisodeExtras(
      subtitles: subtitles,
      qualities: qualities,
      audioLanguages: audioLangs,
      unlocked: raw['unlock'] != false,
      episodePrice: int.tryParse('${raw['episode_price'] ?? 0}') ?? 0,
    );
  }
}
