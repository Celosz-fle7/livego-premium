import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../feed/feed_config.dart';

class LiveGoContentCache {
  LiveGoContentCache._();

  static const int maxItemsPerList = FeedConfig.itemsPerCategory;
  static const int maxJsonCacheBytes = 30 * 1024 * 1024;

  static const Duration homeTtl = FeedConfig.hardHomeCacheTtl;
  static const Duration latestTtl = Duration(hours: 1);
  static const Duration searchTtl = Duration(minutes: 30);
  static const Duration detailTtl = Duration(hours: 24);
  static const Duration episodesTtl = Duration(hours: 24);

  static Future<List<ContentItem>?> readItems({
    required String platform,
    required String endpoint,
    Map<String, String?> params = const {},
    bool allowExpired = false,
  }) async {
    final file = await _file(platform: platform, endpoint: endpoint, params: params);
    final payload = await _readPayload(file, allowExpired: allowExpired);
    if (payload == null) return null;
    final items = payload['items'];
    if (items is! List) return null;
    return items
        .whereType<Map>()
        .map((e) => _contentFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static Future<void> writeItems({
    required String platform,
    required String endpoint,
    required List<ContentItem> items,
    Map<String, String?> params = const {},
    Duration? ttl,
  }) async {
    final file = await _file(platform: platform, endpoint: endpoint, params: params);
    await _writePayload(
      file,
      ttl: ttl ?? _ttlFor(endpoint),
      data: {
        'items': items.take(maxItemsPerList).map(_contentToJson).toList(),
      },
    );
  }

  static Future<ContentItem?> readDetail(ContentItem item) async {
    final file = await _file(
      platform: item.platformSlug,
      endpoint: 'detail',
      params: {'id': item.id},
    );
    final payload = await _readPayload(file);
    final data = payload?['item'];
    if (data is! Map) return null;
    return _contentFromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> writeDetail(ContentItem item) async {
    final file = await _file(
      platform: item.platformSlug,
      endpoint: 'detail',
      params: {'id': item.id},
    );
    await _writePayload(
      file,
      ttl: detailTtl,
      data: {'item': _contentToJson(item)},
    );
  }

  static Future<List<LiveGoEpisode>?> readEpisodes(ContentItem item) async {
    final file = await _file(
      platform: item.platformSlug,
      endpoint: 'episodes',
      params: {'id': item.id},
    );
    final payload = await _readPayload(file);
    final rows = payload?['episodes'];
    if (rows is! List) return null;
    return rows
        .whereType<Map>()
        .map((e) => _episodeFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static Future<void> writeEpisodes(ContentItem item, List<LiveGoEpisode> episodes) async {
    final file = await _file(
      platform: item.platformSlug,
      endpoint: 'episodes',
      params: {'id': item.id},
    );
    await _writePayload(
      file,
      ttl: episodesTtl,
      data: {'episodes': episodes.map(_episodeToJson).toList()},
    );
  }

  static Future<void> cleanExpiredAndTrim() async {
    final root = await _rootDir();
    if (!await root.exists()) return;

    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json')) {
        files.add(entity);
        try {
          final payload = jsonDecode(await entity.readAsString());
          if (payload is Map && _isExpired(Map<String, dynamic>.from(payload))) {
            await entity.delete();
          }
        } catch (_) {
          await entity.delete();
        }
      }
    }

    final remaining = <File>[];
    var total = 0;
    for (final f in files) {
      if (await f.exists()) {
        remaining.add(f);
        total += await f.length();
      }
    }
    if (total <= maxJsonCacheBytes) return;

    remaining.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in remaining) {
      if (total <= maxJsonCacheBytes) break;
      final len = await f.length();
      await f.delete();
      total -= len;
    }
  }

  static Future<Map<String, dynamic>?> _readPayload(File file, {bool allowExpired = false}) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final payload = Map<String, dynamic>.from(decoded);
      if (_isExpired(payload)) {
        if (allowExpired) return payload;
        await file.delete();
        return null;
      }
      return payload;
    } catch (_) {
      try { await file.delete(); } catch (_) {}
      return null;
    }
  }

  static Future<void> _writePayload(
    File file, {
    required Duration ttl,
    required Map<String, dynamic> data,
  }) async {
    try {
      await file.parent.create(recursive: true);
      final payload = <String, dynamic>{
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'ttlSeconds': ttl.inSeconds,
        ...data,
      };
      await file.writeAsString(jsonEncode(payload), flush: false);
      await cleanExpiredAndTrim();
    } catch (e) {
      print('LIVEGO CACHE WRITE ERROR: $e');
    }
  }

  static bool _isExpired(Map<String, dynamic> payload) {
    final created = int.tryParse('${payload['createdAt'] ?? 0}') ?? 0;
    final ttlSeconds = int.tryParse('${payload['ttlSeconds'] ?? 0}') ?? 0;
    if (created <= 0 || ttlSeconds <= 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch - created;
    return age > ttlSeconds * 1000;
  }

  static Duration _ttlFor(String endpoint) {
    final key = endpoint.toLowerCase();
    if (key.contains('latest')) return latestTtl;
    if (key.contains('search')) return searchTtl;
    if (key.contains('detail')) return detailTtl;
    if (key.contains('episode')) return episodesTtl;
    return homeTtl;
  }

  static Future<File> _file({
    required String platform,
    required String endpoint,
    Map<String, String?> params = const {},
  }) async {
    final root = await _rootDir();
    final cleanPlatform = _safe(platform);
    final cleanEndpoint = _safe(endpoint);
    final suffix = params.entries
        .where((e) => (e.value ?? '').isNotEmpty)
        .map((e) => '${_safe(e.key)}_${_safe(e.value!)}')
        .join('_');
    final name = suffix.isEmpty ? '$cleanEndpoint.json' : '${cleanEndpoint}_$suffix.json';
    return File('${root.path}/$cleanPlatform/$name');
  }

  static Future<Directory> _rootDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/livego_cache');
  }

  static String _safe(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '_');
  }

  static Map<String, dynamic> _contentToJson(ContentItem item) => {
        'id': item.id,
        'title': item.title,
        'source': item.source,
        'category': item.category,
        'description': item.description,
        'posterUrl': item.posterUrl,
        'backdropUrl': item.backdropUrl,
        'rating': item.rating,
        'episodes': item.episodes,
        'updated': item.updated,
        'platformSlug': item.platformSlug,
        'chapterId': item.chapterId,
        'lang': item.lang,
      };

  static ContentItem _contentFromJson(Map<String, dynamic> json) => ContentItem(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? 'Untitled'}',
        source: '${json['source'] ?? ''}',
        category: '${json['category'] ?? 'Drama'}',
        description: '${json['description'] ?? ''}',
        posterUrl: '${json['posterUrl'] ?? ''}',
        backdropUrl: '${json['backdropUrl'] ?? json['posterUrl'] ?? ''}',
        rating: double.tryParse('${json['rating'] ?? 8.0}') ?? 8.0,
        episodes: int.tryParse('${json['episodes'] ?? 1}') ?? 1,
        updated: json['updated'] == true,
        platformSlug: '${json['platformSlug'] ?? 'shortmax'}',
        chapterId: '${json['chapterId'] ?? '1'}',
        lang: '${json['lang'] ?? 'id'}',
      );

  static Map<String, dynamic> _episodeToJson(LiveGoEpisode ep) => {
        'id': ep.id,
        'index': ep.index,
        'title': ep.title,
      };

  static LiveGoEpisode _episodeFromJson(Map<String, dynamic> json) => LiveGoEpisode(
        id: '${json['id'] ?? ''}',
        index: int.tryParse('${json['index'] ?? 0}') ?? 0,
        title: '${json['title'] ?? 'Episode ${json['index'] ?? ''}'}',
      );
}
