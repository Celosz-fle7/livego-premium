import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'melolo_client.dart';
import 'melolo_config.dart';

/// Adapter Melolo sebagai DramaSource.
///
/// Protokol (static teardown APK com.worldance.drama 5.3.7, ByteDance):
/// - Host: https://api.tmtreader.com (+ api-my regional)
/// - Param TT: aid=645713 (confirmed dari dex), app_name=melolo, did/iid
///   dari device_register, TANPA header sign native (X-Argus/X-Gorgon
///   tidak direplika — endpoint publik diharapkan tetap menjawab)
/// - Episode: POST /novel/player/video_detail/v1/ {series_id}
///   -> episode_list[] (fallback: multi_video_detail)
/// - Stream: POST /novel/player/video_model/v1/ {series_id, video_id}
///   -> data.videoModel -> VideoInfo{ main_url (direct), backup_url_1..3
///   (Base64-decode), file_id, file_hash } — blueprint bytecode 2026-10-08.
///   Prioritas: main_url dulu, lalu backup_urls[] yang sudah di-decode.
/// - Search: GET /i18n_novel/search/page/v1/ {keyword}
/// - Kategori: GET /i18n_novel/bookmall/tab/v1/ (tab bawaan sinkron di config)
/// - Subtitle: sub_title_list / series_sub_title_list (dukungan app-level,
///   key ada di dex — API kemungkinan mengembalikan)
/// - Audio multi: audio_track / dynamic_audio_list
/// - Kualitas: definition (daftar resolusi dari playinfo)
/// - Paywall: model VIP/unlock (is_vip, need_unlock, auto_unlock),
///   bukan coin per episode. Episode terkunci -> extras.unlocked=false,
///   TIDAK ada bypass.
///
/// CATATAN: struktur respons video_detail/video_model BELUM terverifikasi
/// live (butuh 1 capture runtime dari device). Semua parsing pakai fallback
/// key berlapis; kalau server mengubah format, yang rusak hanya field
/// terkait, bukan seluruh provider.
class MeloloSource implements DramaSource {
  final MeloloClient _client = MeloloClient();

  /// Cache episodeId -> stream URL, diisi saat episodes()/streamUrl().
  /// Format key: "$seriesId:$episodeId".
  final Map<String, String> _streamCache = {};

  /// Cache playinfo mentah per episode untuk extras.
  final Map<String, Map<String, dynamic>> _modelCache = {};

  MeloloClient get client => _client;

  @override
  String get slug => 'melolo';

  @override
  String get label => 'Melolo';

  @override
  List<String> get categories => MeloloConfig.categories;

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    // Coba cocokkan kategori dengan tab asli dari server.
    try {
      final tabs = await _client.tabList();
      final needle = category.toLowerCase();
      Map<String, dynamic>? picked;
      for (final t in tabs) {
        final name = '${t['tab_name'] ?? t['name'] ?? t['title'] ?? ''}'.toLowerCase();
        if (name.isNotEmpty &&
            (name == needle || name.contains(needle) || needle.contains(name))) {
          picked = t;
          break;
        }
      }
      if (picked != null) {
        final tabId = '${picked['tab_id'] ?? picked['id'] ?? ''}';
        if (tabId.isNotEmpty) {
          final items = await _client
              .cellChange({'tab_id': tabId}, category: category);
          if (items.isNotEmpty) return items;
        }
      }
    } catch (_) {
      // Tab gagal -> fallback homepage di bawah.
    }
    return _client.homepage(category: category);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    final data = await _client.videoDetail(seriesId);
    final raw = data['episodes'] as List<Map<String, dynamic>>;
    final out = <LiveGoEpisode>[];
    var idx = 1;
    for (final e in raw) {
      final epNum =
          int.tryParse('${e['episode_num'] ?? e['episode'] ?? e['num'] ?? e['index'] ?? idx}') ??
              idx;
      final vid =
          '${e['video_id'] ?? e['vid'] ?? e['id'] ?? ''}'.isNotEmpty
              ? '${e['video_id'] ?? e['vid'] ?? e['id']}'
              : '$seriesId:$epNum';
      // Stream URL kadang sudah inline di detail episode.
      final inline = _pickStreamUrl(e);
      if (inline.isNotEmpty) _streamCache['$seriesId:$vid'] = inline;
      out.add(LiveGoEpisode(
        id: vid,
        index: epNum,
        title: '${e['title'] ?? e['name'] ?? 'Episode $epNum'}',
      ));
      idx++;
    }
    return out;
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
  }) async {
    final cached = _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) return cached;

    final model = await _client.videoModel(seriesId, episodeId);
    _modelCache['$seriesId:$episodeId'] = model;
    final url = _pickStreamUrl(model);
    if (url.isNotEmpty) {
      _streamCache['$seriesId:$episodeId'] = url;
      return url;
    }
    throw Exception('Melolo: stream URL tidak ditemukan ($seriesId/$episodeId)');
  }

  /// main_url = direct string (TANPA decode); backup_url_1..3 sudah
  /// di-Base64-decode di client menjadi backup_urls[]
  /// (blueprint bytecode 2026-10-08).
  String _pickStreamUrl(Map<String, dynamic> m) {
    final main = '${m['main_url'] ?? ''}';
    if (main.isNotEmpty && main.startsWith('http')) return main;
    final backups = m['backup_urls'];
    if (backups is List) {
      for (final b in backups) {
        final s = '$b';
        if (s.startsWith('http')) return s;
      }
    }
    for (final k in ['play_url', 'video_url', 'url', 'm3u8_url', 'stream_url']) {
      final v = '${m[k] ?? ''}';
      if (v.isNotEmpty && v.startsWith('http')) return v;
    }
    // Kadang URL ada di dalam objek video bersarang.
    final video = m['video'];
    if (video is Map<String, dynamic>) {
      final nested = _pickStreamUrl(video);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) {
    return _client.searchPage(query);
  }

  /// Paywall Melolo: model VIP/unlock (is_vip, need_unlock), bukan coin.
  bool _isLocked(Map<String, dynamic> model) {
    for (final k in [
      'need_unlock',
      'is_locked',
      'need_vip',
      'is_vip_limit'
    ]) {
      final s = '${model[k] ?? ''}'.toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
    }
    return false;
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    var model = _modelCache['$seriesId:$episodeId'];
    if (model == null) {
      try {
        await streamUrl(seriesId: seriesId, episodeId: episodeId);
      } catch (_) {
        return null;
      }
      model = _modelCache['$seriesId:$episodeId'];
    }
    if (model == null) return null;

    // Subtitle: sub_title_list / series_sub_title_list (dukungan app-level).
    final subtitles = <DramaSubtitle>[];
    final seenSub = <String>{};
    final subRaw = model['sub_title_list'] ??
        model['series_sub_title_list'] ??
        model['subtitles'];
    if (subRaw is List) {
      for (final s in subRaw) {
        if (s is! Map) continue;
        final url = '${s['url'] ?? s['sub_url'] ?? ''}';
        if (url.isEmpty || !seenSub.add(url)) continue;
        subtitles.add(DramaSubtitle(
          language: '${s['lang'] ?? s['language'] ?? s['code'] ?? 'und'}',
          displayName:
              '${s['sub_title_show_name'] ?? s['name'] ?? s['display_name'] ?? s['lang'] ?? 'Subtitle'}',
          url: url,
        ));
      }
    }

    // Kualitas: definition (daftar resolusi dari playinfo).
    final qualities = <DramaQuality>[];
    final seenQ = <String>{};
    final defRaw = model['definition'] ?? model['definitions'] ?? model['bitrates'];
    if (defRaw is List) {
      for (final d in defRaw) {
        final label = d is Map
            ? '${d['name'] ?? d['label'] ?? d['definition'] ?? ''}'
            : '$d';
        if (label.isNotEmpty && seenQ.add(label)) {
          qualities.add(DramaQuality(label: label, resolution: label));
        }
      }
    }

    // Audio multi: audio_track / dynamic_audio_list.
    final audioLangs = <String>[];
    final seenA = <String>{};
    final audRaw =
        model['audio_track'] ?? model['dynamic_audio_list'] ?? model['audios'];
    if (audRaw is List) {
      for (final a in audRaw) {
        final s = a is Map
            ? '${a['name'] ?? a['label'] ?? a['lang'] ?? a['language'] ?? ''}'
            : '$a';
        if (s.isNotEmpty && seenA.add(s)) audioLangs.add(s);
      }
    }

    return DramaEpisodeExtras(
      subtitles: subtitles,
      qualities: qualities,
      audioLanguages: audioLangs,
      unlocked: !_isLocked(model),
      episodePrice: 0,
    );
  }
}
