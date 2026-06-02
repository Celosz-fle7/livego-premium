import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/content_item.dart';

class BadContentRecord {
  final String key;
  final String platform;
  final String id;
  final String title;
  final String cover;
  final String reason;
  final int failCount;
  final DateTime failedAt;
  final DateTime resetAt;

  const BadContentRecord({
    required this.key,
    required this.platform,
    required this.id,
    required this.title,
    required this.cover,
    required this.reason,
    required this.failCount,
    required this.failedAt,
    required this.resetAt,
  });

  bool get expired => DateTime.now().isAfter(resetAt);

  Map<String, dynamic> toJson() => {
        'key': key,
        'platform': platform,
        'id': id,
        'title': title,
        'cover': cover,
        'reason': reason,
        'failCount': failCount,
        'failedAt': failedAt.toIso8601String(),
        'resetAt': resetAt.toIso8601String(),
      };

  static BadContentRecord? fromJson(Map<String, dynamic> json) {
    final key = '${json['key'] ?? ''}'.trim();
    if (key.isEmpty) return null;
    return BadContentRecord(
      key: key,
      platform: '${json['platform'] ?? ''}',
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      cover: '${json['cover'] ?? ''}',
      reason: '${json['reason'] ?? 'video_not_playable'}',
      failCount: _parseInt(json['failCount'], fallback: 1),
      failedAt: DateTime.tryParse('${json['failedAt'] ?? ''}') ?? DateTime.now(),
      resetAt: DateTime.tryParse('${json['resetAt'] ?? ''}') ?? DateTime.now().add(const Duration(days: 7)),
    );
  }

  static int _parseInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }
}

class ContentHealthService {
  const ContentHealthService._();

  static const _badContentKey = 'livego.bad_content.v2';
  static final Map<String, BadContentRecord> _bad = <String, BadContentRecord>{};
  static SharedPreferences? _prefs;
  static bool _ready = false;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    await cleanExpired();
    _ready = true;
  }

  static String contentKey(ContentItem item) {
    final platform = item.platformSlug.trim().toLowerCase();
    final id = item.id.trim();
    return '$platform:$id';
  }

  static bool isBlocked(ContentItem item) {
    _ensureLoaded();
    final record = _bad[contentKey(item)];
    if (record == null) return false;
    if (record.expired) {
      _bad.remove(record.key);
      _persist();
      return false;
    }
    return true;
  }

  static Future<void> markPlayable(ContentItem item) async {
    _ensureLoaded();
    final key = contentKey(item);
    if (_bad.remove(key) != null) {
      await _persist();
      if (kDebugMode) debugPrint('LIVEGO CONTENT RESTORED $key');
    }
  }

  static Future<bool> markBroken(
    ContentItem item, {
    String reason = 'video_not_playable',
    int days = 7,
    int failCount = 3,
  }) async {
    _ensureLoaded();

    // Jangan sembunyikan konten karena jaringan user, server down, rate limit,
    // quota, timestamp HMAC, atau timeout sementara.
    if (!shouldBlockContent(reason)) {
      if (kDebugMode) debugPrint('LIVEGO CONTENT NOT BLOCKED transient/unknown reason=$reason');
      return false;
    }

    final now = DateTime.now();
    final key = contentKey(item);
    _bad[key] = BadContentRecord(
      key: key,
      platform: item.platformSlug,
      id: item.id,
      title: item.title,
      cover: item.posterUrl,
      reason: reason,
      failCount: failCount,
      failedAt: now,
      resetAt: now.add(Duration(days: days)),
    );
    await _persist();
    if (kDebugMode) debugPrint('LIVEGO CONTENT BLOCKED $key reason=$reason days=$days');
    return true;
  }

  static bool shouldAutoSkip(String reason) {
    return !isTransientFailure(reason);
  }

  static bool shouldBlockContent(String reason) {
    if (isTransientFailure(reason)) return false;
    final r = reason.toLowerCase();

    // Ini indikasi konten/episode rusak dari source/API, bukan jaringan user.
    return r.contains('stream belum tersedia') ||
        r.contains('stream kosong') ||
        r.contains('stream_empty') ||
        r.contains('url video kosong') ||
        r.contains('url kosong') ||
        r.contains('source error') ||
        r.contains('failed to load video') ||
        r.contains('video format') ||
        r.contains('not found') ||
        r.contains('404') ||
        r.contains('unavailable') ||
        r.contains('not playable') ||
        r.contains('unsupported') ||
        r.contains('encrypted') ||
        r.contains('decrypt');
  }

  static bool isTransientFailure(String reason) {
    final r = reason.toLowerCase();
    return r.contains('timeout') ||
        r.contains('timed out') ||
        r.contains('socketexception') ||
        r.contains('failed host lookup') ||
        r.contains('network is unreachable') ||
        r.contains('connection') ||
        r.contains('connection reset') ||
        r.contains('connection refused') ||
        r.contains('handshakeexception') ||
        r.contains('certificate') ||
        r.contains('server') ||
        r.contains('500') ||
        r.contains('502') ||
        r.contains('503') ||
        r.contains('504') ||
        r.contains('429') ||
        r.contains('rate') ||
        r.contains('quota') ||
        r.contains('expired_timestamp') ||
        r.contains('forbidden') ||
        r.contains('401') ||
        r.contains('403');
  }

  static Future<void> cleanExpired() async {
    _ensureLoaded();
    final before = _bad.length;
    _bad.removeWhere((_, record) => record.expired);
    if (_bad.length != before) await _persist();
  }

  static List<ContentItem> filterPlayable(Iterable<ContentItem> rows) {
    _ensureLoaded();
    final out = <ContentItem>[];
    final seenId = <String>{};
    final seenTitle = <String>{};

    for (final item in rows) {
      if (!_isValidFeedItem(item)) continue;
      if (isBlocked(item)) continue;

      final idKey = contentKey(item);
      if (!seenId.add(idKey)) continue;

      final titleKey = duplicateKey(item);
      if (titleKey.isNotEmpty && !seenTitle.add(titleKey)) continue;

      out.add(item);
    }
    return out;
  }

  static String duplicateKey(ContentItem item) {
    final title = normalizeTitle(item.title);
    if (title.length < 4) return '';
    final episodePart = item.episodes > 0 ? ':${item.episodes}' : '';
    final sourceGroup = item.platformSlug.toLowerCase().startsWith('dobda_') ? 'dobda' : item.platformSlug.toLowerCase();
    return '$sourceGroup:$title$episodePart';
  }

  static String normalizeTitle(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\b(dub|dubbing|sulih|suara|versi|bahasa|indonesia|indo)\b'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isValidFeedItem(ContentItem item) {
    if (item.id.trim().isEmpty) return false;
    if (item.title.trim().isEmpty || item.title.trim().toLowerCase() == 'untitled') return false;
    final cover = item.posterUrl.trim();
    if (cover.isEmpty || cover.endsWith('url=')) return false;
    if (item.episodes <= 0) return false;
    return true;
  }

  static List<BadContentRecord> get blockedItems {
    _ensureLoaded();
    return _bad.values.where((e) => !e.expired).toList()
      ..sort((a, b) => b.failedAt.compareTo(a.failedAt));
  }

  static void _load() {
    _bad.clear();
    final raw = _prefs?.getString(_badContentKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final row in decoded) {
        if (row is! Map) continue;
        final record = BadContentRecord.fromJson(Map<String, dynamic>.from(row));
        if (record != null && !record.expired) _bad[record.key] = record;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('LIVEGO CONTENT HEALTH LOAD ERROR: $e');
    }
  }

  static Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_badContentKey, jsonEncode(_bad.values.map((e) => e.toJson()).toList()));
  }

  static void _ensureLoaded() {
    if (_ready) return;
  }
}
