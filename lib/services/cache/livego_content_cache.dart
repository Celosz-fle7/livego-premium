import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'livego_cache_observer.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../feed/feed_config.dart';

class LiveGoContentCache {
  LiveGoContentCache._();

  static const int maxHomeItemsPerList = FeedConfig.itemsPerCategory;
  static const int maxSearchItemsPerList = 24;
  static const int maxEpisodeRowsPerItem = 80;
  static const int maxHomeJsonCacheBytes = 6 * 1024 * 1024;
  static const int maxPlayerJsonCacheBytes = 3 * 1024 * 1024;
  static const int maxSearchJsonCacheBytes = 2 * 1024 * 1024;

  static const Duration homeTtl = FeedConfig.homeApiTtl;
  static const Duration latestTtl = Duration(hours: 1);
  static const Duration searchTtl = Duration(minutes: 30);
  static const Duration detailTtl = Duration(minutes: 30);
  static const Duration episodesTtl = Duration(minutes: 20);

  static Future<List<ContentItem>?> readItems({
    required String platform,
    required String endpoint,
    Map<String, String?> params = const {},
    bool allowExpired = false,
  }) async {
    final domain = _domainFor(endpoint);
    final file = await _file(platform: platform, endpoint: endpoint, params: params, domain: domain);
    final payload = await _readPayload(file, allowExpired: allowExpired, domain: domain, key: '$platform/$endpoint');
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
    final domain = _domainFor(endpoint);
    final limit = _maxItemsFor(endpoint);
    final rows = items.take(limit).toList(growable: false);
    final file = await _file(platform: platform, endpoint: endpoint, params: params, domain: domain);
    await _writePayload(
      file,
      ttl: _effectiveTtl(endpoint, ttl),
      domain: domain,
      key: '$platform/$endpoint',
      data: {
        'domain': domain,
        'items': rows.map(_contentToJson).toList(),
      },
    );
  }

  static Future<ContentItem?> readDetail(ContentItem item) async {
    final file = await _file(
      platform: item.platformSlug,
      endpoint: 'detail',
      params: {'id': item.id},
      domain: 'player',
    );
    final payload = await _readPayload(file, domain: 'player', key: _itemKey(item));
    final data = payload?['item'];
    if (data is! Map) return null;
    return _contentFromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> writeDetail(ContentItem item) async {
    final file = await _file(
      platform: item.platformSlug,
      endpoint: 'detail',
      params: {'id': item.id},
      domain: 'player',
    );
    await _writePayload(
      file,
      ttl: detailTtl,
      domain: 'player',
      key: _itemKey(item),
      data: {'domain': 'player', 'item': _contentToJson(item)},
    );
  }

  static Future<List<LiveGoEpisode>?> readEpisodes(ContentItem item) async {
    final file = await _file(
      platform: item.platformSlug,
      endpoint: 'episodes',
      params: {'id': item.id},
      domain: 'player',
    );
    final payload = await _readPayload(file, domain: 'player', key: _itemKey(item));
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
      domain: 'player',
    );
    final rows = episodes.take(maxEpisodeRowsPerItem).toList(growable: false);
    await _writePayload(
      file,
      ttl: episodesTtl,
      domain: 'player',
      key: _itemKey(item),
      data: {'domain': 'player', 'episodes': rows.map(_episodeToJson).toList()},
    );
  }

  static Future<void> clearAll() async {
    final root = await _rootDir();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    LiveGoCacheObserver.log('cache_cleanup_done', domain: 'content', reason: 'clear_all_temporary_content_cache');
  }

  static Future<void> clearHomeCache() => _clearDomain('home');

  static Future<void> clearPlayerCache() => _clearDomain('player');

  static Future<void> clearSearchCache() => _clearDomain('search');

  static Future<void> _clearDomain(String domain) async {
    final dir = Directory('${(await _rootDir()).path}/$domain');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    LiveGoCacheObserver.log('cache_cleanup_done', domain: domain, reason: 'clear_${domain}_content_cache');
  }

  static Future<void> cleanExpiredAndTrim() async {
    for (final domain in const <String>['home', 'player', 'search']) {
      await _cleanExpiredAndTrimDomain(domain);
    }
  }

  static Future<void> _cleanExpiredAndTrimDomain(String domain) async {
    final root = Directory('${(await _rootDir()).path}/$domain');
    if (!await root.exists()) return;

    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json')) {
        files.add(entity);
        try {
          final payload = jsonDecode(await entity.readAsString());
          if (payload is Map && _isExpired(Map<String, dynamic>.from(payload))) {
            await entity.delete();
            LiveGoCacheObserver.log('cache_cleanup_done', domain: domain, key: entity.path, expired: true, reason: 'expired_json');
          }
        } catch (_) {
          await entity.delete();
          LiveGoCacheObserver.log('cache_cleanup_done', domain: domain, key: entity.path, reason: 'corrupt_json');
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
    final limit = _maxBytesForDomain(domain);
    if (total <= limit) return;

    remaining.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in remaining) {
      if (total <= limit) break;
      final len = await f.length();
      await f.delete();
      total -= len;
      LiveGoCacheObserver.log('cache_cleanup_done', domain: domain, key: f.path, estimatedBytes: len, reason: 'domain_size_limit');
    }
  }

  static Future<Map<String, dynamic>?> _readPayload(File file, {bool allowExpired = false, required String domain, required String key}) async {
    try {
      if (!await file.exists()) {
        LiveGoCacheObserver.log(domain == 'home' ? 'home_cache_miss' : 'cache_miss', domain: domain, key: key);
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final payload = Map<String, dynamic>.from(decoded);
      if (_isExpired(payload)) {
        LiveGoCacheObserver.log(domain == 'home' ? 'home_cache_expired' : 'cache_expired', domain: domain, key: key, expired: true);
        if (allowExpired) return payload;
        await file.delete();
        return null;
      }
      LiveGoCacheObserver.log(domain == 'home' ? 'home_cache_hit' : 'cache_hit', domain: domain, key: key);
      return payload;
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {}
      LiveGoCacheObserver.log('cache_cleanup_done', domain: domain, key: key, reason: 'read_error');
      return null;
    }
  }

  static Future<void> _writePayload(
    File file, {
    required Duration ttl,
    required String domain,
    required String key,
    required Map<String, dynamic> data,
  }) async {
    try {
      await file.parent.create(recursive: true);
      final payload = <String, dynamic>{
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'ttlSeconds': ttl.inSeconds,
        ...data,
      };
      final encoded = jsonEncode(payload);
      await file.writeAsString(encoded, flush: false);
      LiveGoCacheObserver.log(domain == 'home' ? 'home_cache_saved' : 'cache_saved', domain: domain, key: key, itemCount: _payloadItemCount(data), estimatedBytes: encoded.length, ttl: ttl);
      await _cleanExpiredAndTrimDomain(domain);
    } catch (e) {
      LiveGoCacheObserver.log('cache_write_error', domain: domain, key: key, reason: '$e');
    }
  }

  static bool _isExpired(Map<String, dynamic> payload) {
    final created = int.tryParse('${payload['createdAt'] ?? 0}') ?? 0;
    final ttlSeconds = int.tryParse('${payload['ttlSeconds'] ?? 0}') ?? 0;
    if (created <= 0 || ttlSeconds <= 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch - created;
    return age > ttlSeconds * 1000;
  }


  static String _domainFor(String endpoint) {
    final key = endpoint.toLowerCase();
    if (key.contains('search')) return 'search';
    if (key.contains('detail') || key.contains('episode')) return 'player';
    return 'home';
  }

  static int _maxItemsFor(String endpoint) {
    final domain = _domainFor(endpoint);
    if (domain == 'search') return maxSearchItemsPerList;
    if (domain == 'player') return maxEpisodeRowsPerItem;
    return maxHomeItemsPerList;
  }

  static int _maxBytesForDomain(String domain) {
    switch (domain) {
      case 'player':
        return maxPlayerJsonCacheBytes;
      case 'search':
        return maxSearchJsonCacheBytes;
      case 'home':
      default:
        return maxHomeJsonCacheBytes;
    }
  }

  static int? _payloadItemCount(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is List) return items.length;
    final episodes = data['episodes'];
    if (episodes is List) return episodes.length;
    return data['item'] == null ? null : 1;
  }

  static String _itemKey(ContentItem item) => '${item.platformSlug}/${item.id}';

  static Duration _effectiveTtl(String endpoint, Duration? requested) {
    final fallback = _ttlFor(endpoint);
    final ttl = requested ?? fallback;
    final domain = _domainFor(endpoint);
    if (domain == 'home' && ttl > homeTtl) return homeTtl;
    if (domain == 'player' && ttl > detailTtl) return detailTtl;
    return ttl;
  }

  static Duration _ttlFor(String endpoint) {
    final key = endpoint.toLowerCase();
    if (key == 'home' || key == 'home_clean_v2') return FeedConfig.homeApiTtl;
    if (key == 'livego' || key.contains('livego')) return FeedConfig.liveGoRecommendationTtl;
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
    required String domain,
  }) async {
    final root = Directory('${(await _rootDir()).path}/$domain');
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
        platformSlug: '${json['platformSlug'] ?? 'dobda_freereels'}',
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
