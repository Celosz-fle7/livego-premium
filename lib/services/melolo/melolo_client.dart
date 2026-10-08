import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/content_item.dart';
import 'melolo_config.dart';

/// HTTP client Melolo — meniru request APK (ByteDance TT stack).
///
/// Alur identitas:
/// 1. device_register (ByteDance standar, biasanya lolos tanpa signing)
///    -> device_id (did) + install_id (iid), persisten per install.
/// 2. Semua request API bawa param TT: aid=645713, app_name=melolo,
///    version_code, device_id, iid, did, device_brand/type, os, resolution...
/// 3. Header sign X-Argus/X-Gorgon TIDAK direplika (native) — request
///    dikirim tanpa; kalau server menolak, error-nya jelas di exception.
///
/// Parsing toleran: struktur respons video_detail/video_model belum
/// terverifikasi live (butuh 1 capture runtime), jadi semua akses field
/// pakai fallback key berlapis.
class MeloloClient {
  String _host = MeloloConfig.primaryHost;
  String? _deviceId;
  String? _installId;
  bool _registerTried = false;

  /// Param TT umum (dari dex + probe script).
  Map<String, String> _commonParams() {
    return {
      'aid': MeloloConfig.aid,
      'app_name': MeloloConfig.appName,
      'version_code': MeloloConfig.versionCode,
      'device_brand': 'OPPO',
      'device_type': 'CPH2205',
      'os': 'android',
      'os_version': '13',
      'os_api': '33',
      'resolution': '1080*2400',
      'tz_name': 'Asia/Jakarta',
      'channel': 'official',
    };
  }

  Future<Map<String, String>> _identity() async {
    if (_deviceId != null && _installId != null) {
      return {'device_id': _deviceId!, 'iid': _installId!, 'did': _deviceId!};
    }
    final prefs = await SharedPreferences.getInstance();
    var did = prefs.getString(MeloloConfig.deviceIdPrefKey);
    var iid = prefs.getString(MeloloConfig.installIdPrefKey);
    if (did == null || did.isEmpty || iid == null || iid.isEmpty) {
      final reg = await _deviceRegister();
      did = reg['device_id'];
      iid = reg['install_id'];
      if (did == null || did.isEmpty) {
        // Register gagal — pakai identitas acak; endpoint publik
        // kemungkinan tetap menjawab.
        final rnd = Random.secure();
        did = List<int>.generate(8, (_) => rnd.nextInt(256))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        iid = List<int>.generate(8, (_) => rnd.nextInt(256))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
      }
      await prefs.setString(MeloloConfig.deviceIdPrefKey, did);
      await prefs.setString(MeloloConfig.installIdPrefKey, iid ?? '');
    }
    _deviceId = did;
    _installId = iid;
    return {'device_id': did!, 'iid': iid ?? '', 'did': did};
  }

  /// POST device_register (ByteDance). Return {device_id, install_id} atau kosong.
  Future<Map<String, String>> _deviceRegister() async {
    if (_registerTried) return const {};
    _registerTried = true;
    final out = <String, String>{};
    try {
      final client = HttpClient();
      try {
        final uri = Uri.parse(MeloloConfig.deviceRegisterPath);
        final req = await client.postUrl(uri).timeout(MeloloConfig.timeout);
        req.headers.set('User-Agent', MeloloConfig.userAgent);
        req.headers.set('Content-Type',
            'application/x-www-form-urlencoded; charset=UTF-8');
        final body = <String, String>{
          ..._commonParams(),
          'device_id': '0',
          'iid': '0',
        };
        req.write(Uri(queryParameters: body).query);
        final resp = await req.close().timeout(MeloloConfig.timeout);
        final text = await resp.transform(utf8.decoder).join();
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final decoded = jsonDecode(text);
          final data = decoded is Map ? (decoded['data'] ?? decoded) : {};
          if (data is Map) {
            final did = '${data['device_id'] ?? data['did'] ?? ''}';
            final iid = '${data['install_id'] ?? data['iid'] ?? ''}';
            if (did.isNotEmpty && did != '0') out['device_id'] = did;
            if (iid.isNotEmpty && iid != '0') out['install_id'] = iid;
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
    return out;
  }

  Uri _uri(String path, [Map<String, String>? extra]) {
    final params = <String, String>{
      ..._commonParams(),
      ...?extra,
    };
    return Uri.parse('$_host$path').replace(queryParameters: params);
  }

  /// GET {host}{path} + param TT. Return Map decoded (toleran).
  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final id = await _identity();
    final uri = _uri(path, {...id, ...?query});
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri).timeout(MeloloConfig.timeout);
      req.headers.set('User-Agent', MeloloConfig.userAgent);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close().timeout(MeloloConfig.timeout);
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Melolo ${resp.statusCode} $path: ${_short(text)}');
      }
      return _decode(text);
    } finally {
      client.close(force: true);
    }
  }

  /// POST form {host}{path} + param TT. Return Map decoded (toleran).
  Future<Map<String, dynamic>> _postForm(
    String path,
    Map<String, String> fields,
  ) async {
    final id = await _identity();
    final uri = _uri(path, id);
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri).timeout(MeloloConfig.timeout);
      req.headers.set('User-Agent', MeloloConfig.userAgent);
      req.headers.set('Accept', 'application/json');
      req.headers.set(
          'Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
      if (fields.isNotEmpty) {
        req.write(Uri(queryParameters: fields).query);
      }
      final resp = await req.close().timeout(MeloloConfig.timeout);
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Melolo ${resp.statusCode} $path: ${_short(text)}');
      }
      return _decode(text);
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _decode(String text) {
    final t = text.trim();
    if (t.isEmpty) return const {};
    final decoded = jsonDecode(t);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'data': decoded};
  }

  String _short(String s) => s.length > 160 ? '${s.substring(0, 160)}...' : s;

  /// Ambil data efektif: {code, data} -> data; atau map langsung.
  /// Throw kalau code jelas error (mis. 123 = invalid aid).
  Map<String, dynamic> _dataOf(String path, Map<String, dynamic> res) {
    final code = res['code'];
    if (code != null) {
      final c = int.tryParse('$code');
      // 0 = sukses (konvensi umum); 123 = invalid aid (terverifikasi).
      if (c != null && c != 0) {
        throw Exception(
            'Melolo code=$c msg=${res['message'] ?? res['msg']} path=$path');
      }
    }
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return <String, dynamic>{'list': data};
    return res;
  }

  List<Map> _asMaps(Object? raw) {
    if (raw is List) return raw.whereType<Map>().toList();
    return const [];
  }

  ContentItem _toContentItem(Map m, String category) {
    final id = '${m['series_id'] ?? m['book_id'] ?? m['id'] ?? ''}';
    return ContentItem(
      id: id,
      title: '${m['title'] ?? m['name'] ?? m['book_name'] ?? 'No title'}',
      source: 'melolo',
      category: category,
      description:
          '${m['description'] ?? m['desc'] ?? m['synopsis'] ?? m['introduction'] ?? ''}',
      posterUrl:
          '${m['cover'] ?? m['poster'] ?? m['cover_url'] ?? m['image'] ?? m['thumb'] ?? ''}',
      backdropUrl:
          '${m['cover'] ?? m['poster'] ?? m['cover_url'] ?? m['image'] ?? ''}',
      rating: double.tryParse('${m['score'] ?? m['rating'] ?? 0}') ?? 0,
      episodes:
          int.tryParse('${m['total_episode'] ?? m['episode_count'] ?? m['chapters'] ?? 0}') ??
              0,
      platformSlug: 'melolo',
    );
  }

  List<ContentItem> _itemsFrom(Object? raw, String category) {
    return _asMaps(raw)
        .map((m) => _toContentItem(m, category))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// GET /i18n_novel/bookmall/tab/v1/ -> daftar tab kategori.
  Future<List<Map<String, dynamic>>> tabList() async {
    final data = _dataOf('tab', await _get(MeloloConfig.tabPath));
    final list = _asMaps(data['tab_list'] ??
        data['tabs'] ??
        data['list'] ??
        data['items']);
    return list.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// GET /i18n_novel/userapi/get_homepage/v1/ -> feed homepage.
  Future<List<ContentItem>> homepage({String category = ''}) async {
    final data = _dataOf('homepage', await _get(MeloloConfig.homepagePath));
    return _itemsFrom(
        data['cell_list'] ?? data['list'] ?? data['items'] ?? data['feeds'],
        category);
  }

  /// GET /i18n_novel/bookmall/cell/change/v1/ -> konten per cell/tab.
  Future<List<ContentItem>> cellChange(Map<String, String> query,
      {String category = ''}) async {
    final data =
        _dataOf('cell/change', await _get(MeloloConfig.cellChangePath, query));
    return _itemsFrom(
        data['cell_list'] ?? data['list'] ?? data['items'], category);
  }

  /// GET /i18n_novel/search/page/v1/ {keyword} -> hasil pencarian.
  Future<List<ContentItem>> searchPage(String keyword) async {
    final data = _dataOf('search',
        await _get(MeloloConfig.searchPagePath, {'keyword': keyword}));
    return _itemsFrom(
        data['list'] ?? data['items'] ?? data['results'], 'search');
  }

  /// POST /novel/player/video_detail/v1/ {series_id} -> detail + episode.
  ///
  /// Return: { 'info': <Map>, 'episodes': <List<Map>> }.
  /// Struktur respons belum terverifikasi live — fallback key berlapis.
  Future<Map<String, dynamic>> videoDetail(String seriesId) async {
    var data = _dataOf('video_detail',
        await _postForm(MeloloConfig.videoDetailPath, {'series_id': seriesId}));
    // Coba varian multi kalau video_detail kosong.
    if (_asMaps(data['episode_list']).isEmpty &&
        _asMaps(data['episodes']).isEmpty &&
        _asMaps(data['list']).isEmpty) {
      try {
        data = _dataOf('multi_video_detail', await _postForm(
            MeloloConfig.multiVideoDetailPath, {'series_id': seriesId}));
      } catch (_) {}
    }
    final info = (data['video_info'] ??
        data['series_info'] ??
        data['info'] ??
        data['detail'] ??
        {}) as Map? ??
        {};
    final episodes = _asMaps(data['episode_list'] ??
            data['episodes'] ??
            data['video_list'] ??
            data['list'])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return {
      'info': Map<String, dynamic>.from(info),
      'episodes': episodes,
    };
  }

  /// POST /novel/player/video_model/v1/ -> playinfo satu episode.
  ///
  /// Struktur TERKONFIRMASI (blueprint bytecode 2026-10-08):
  ///   response.data.videoModel -> VideoInfo{ main_url (direct string),
  ///   backup_url_1..3 (Base64-encoded), file_id, file_hash }
  ///   response.data juga bawa: authorization, expireTime, playAuthToken,
  ///   videoWidth, videoHeight.
  /// Return map ternormalisasi (atau kosong kalau gagal).
  Future<Map<String, dynamic>> videoModel(
      String seriesId, String videoId) async {
    final fields = <String, String>{
      'series_id': seriesId,
      'video_id': videoId,
    };
    Map<String, dynamic> data = const {};
    try {
      data = _dataOf('video_model',
          await _postForm(MeloloConfig.videoModelPath, fields));
    } catch (_) {}
    if (data.isEmpty) {
      // Varian multi sebagai fallback.
      try {
        data = _dataOf('multi_video_model',
            await _postForm(MeloloConfig.multiVideoModelPath, fields));
      } catch (_) {}
    }
    if (data.isEmpty) return const {};
    return _normalizeVideoModel(data);
  }

  /// Normalisasi data.videoModel sesuai blueprint:
  /// main_url = direct string; backup_url_1..3 di-Base64-decode -> backup_urls[].
  Map<String, dynamic> _normalizeVideoModel(Map<String, dynamic> data) {
    final rawVm = data['videoModel'] ??
        data['video_model'] ??
        data['model'] ??
        data['play_info'] ??
        data;
    final Map<String, dynamic> vm = rawVm is Map<String, dynamic>
        ? rawVm
        : rawVm is Map
            ? Map<String, dynamic>.from(rawVm)
            : <String, dynamic>{};
    final out = Map<String, dynamic>.from(vm);

    final backups = <String>[];
    void addBackup(Object? v) {
      final s = '$v'.trim();
      if (s.isEmpty || s == 'null') return;
      final dec = _tryBase64(s);
      final url = dec.isNotEmpty ? dec : s;
      if (url.startsWith('http') && !backups.contains(url)) backups.add(url);
    }

    addBackup(vm['backup_url_1']);
    addBackup(vm['backup_url_2']);
    addBackup(vm['backup_url_3']);
    addBackup(vm['backup_url']);
    out['backup_urls'] = backups;

    // Metadata level data (kalau belum ada di videoModel).
    out['expire_time'] ??= data['expireTime'] ?? data['expire_time'];
    out['play_auth_token'] ??= data['playAuthToken'] ?? data['play_auth_token'];
    out['video_width'] ??= data['videoWidth'] ?? data['video_width'];
    out['video_height'] ??= data['videoHeight'] ?? data['video_height'];
    out['authorization'] ??= data['authorization'];
    return out;
  }

  /// Base64 decode toleran (URL-safe + padding otomatis). '' kalau gagal.
  String _tryBase64(String s) {
    try {
      var t = s
          .replaceAll('-', '+')
          .replaceAll('_', '/')
          .replaceAll(RegExp(r'\s'), '');
      final mod = t.length % 4;
      if (mod != 0) t += '=' * (4 - mod);
      return utf8.decode(base64.decode(t));
    } catch (_) {
      return '';
    }
  }
}
