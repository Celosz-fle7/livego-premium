import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_item.dart';
import '../services/content/content_health_service.dart';
import 'livego_settings.dart';

class WatchProgress {
  final ContentItem item;
  final int episode;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  const WatchProgress({
    required this.item,
    required this.episode,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  double get ratio {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'item': LiveGoLocalStore.itemToJson(item),
        'episode': episode,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static WatchProgress? fromJson(Map<String, dynamic> json) {
    final itemRaw = json['item'];
    if (itemRaw is! Map) return null;
    final item = LiveGoLocalStore.itemFromJson(Map<String, dynamic>.from(itemRaw));
    return WatchProgress(
      item: item,
      episode: LiveGoLocalStore.parseInt(json['episode'], fallback: 1),
      position: Duration(milliseconds: LiveGoLocalStore.parseInt(json['positionMs'], fallback: 0)),
      duration: Duration(milliseconds: LiveGoLocalStore.parseInt(json['durationMs'], fallback: 0)),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}

enum DownloadStatus { queued, downloading, completed, failed, canceled }

class DownloadRecord {
  final ContentItem item;
  final int episode;
  final String quality;
  final String url;
  final String localPath;
  final double progress;
  final DownloadStatus status;
  final DateTime updatedAt;
  final String error;

  const DownloadRecord({
    required this.item,
    required this.episode,
    required this.quality,
    required this.url,
    required this.localPath,
    required this.progress,
    required this.status,
    required this.updatedAt,
    this.error = '',
  });

  String get key => '${item.platformSlug}:${item.id}:$episode:$quality';

  DownloadRecord copyWith({
    String? localPath,
    double? progress,
    DownloadStatus? status,
    DateTime? updatedAt,
    String? error,
  }) {
    return DownloadRecord(
      item: item,
      episode: episode,
      quality: quality,
      url: url,
      localPath: localPath ?? this.localPath,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'item': LiveGoLocalStore.itemToJson(item),
        'episode': episode,
        'quality': quality,
        'url': url,
        'localPath': localPath,
        'progress': progress,
        'status': status.name,
        'updatedAt': updatedAt.toIso8601String(),
        'error': error,
      };

  static DownloadRecord? fromJson(Map<String, dynamic> json) {
    final itemRaw = json['item'];
    if (itemRaw is! Map) return null;
    final statusName = '${json['status'] ?? 'queued'}';
    return DownloadRecord(
      item: LiveGoLocalStore.itemFromJson(Map<String, dynamic>.from(itemRaw)),
      episode: LiveGoLocalStore.parseInt(json['episode'], fallback: 1),
      quality: '${json['quality'] ?? 'Auto'}',
      url: '${json['url'] ?? ''}',
      localPath: '${json['localPath'] ?? ''}',
      progress: double.tryParse('${json['progress'] ?? '0'}') ?? 0,
      status: DownloadStatus.values.firstWhere((e) => e.name == statusName, orElse: () => DownloadStatus.queued),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
      error: '${json['error'] ?? ''}',
    );
  }
}

class LiveGoLocalStore {
  static const _historyKey = 'livego.history.v2';
  static const _favoritesKey = 'livego.favorites.v2';
  static const _progressKey = 'livego.progress.v2';
  static const _downloadsKey = 'livego.downloads.v2';
  static const _settingsKey = 'livego.settings.v3';

  static final ValueNotifier<int> version = ValueNotifier<int>(0);
  static final List<ContentItem> _history = <ContentItem>[];
  static final List<ContentItem> _favorites = <ContentItem>[];
  static final Map<String, WatchProgress> _progress = <String, WatchProgress>{};
  static final List<DownloadRecord> _downloads = <DownloadRecord>[];
  static SharedPreferences? _prefs;

  static List<ContentItem> get history => List.unmodifiable(_history);
  static List<ContentItem> get favorites => List.unmodifiable(_favorites);
  static List<DownloadRecord> get downloads => List.unmodifiable(_downloads);
  static List<WatchProgress> get continueWatching {
    final rows = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(rows);
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    await ContentHealthService.init();
    _history
      ..clear()
      ..addAll(_decodeList(_prefs?.getString(_historyKey)).map(itemFromJson));
    _favorites
      ..clear()
      ..addAll(_decodeList(_prefs?.getString(_favoritesKey)).map(itemFromJson));
    _progress.clear();
    for (final row in _decodeList(_prefs?.getString(_progressKey))) {
      final progress = WatchProgress.fromJson(row);
      if (progress != null) _progress[_key(progress.item)] = progress;
    }
    _downloads
      ..clear()
      ..addAll(_decodeList(_prefs?.getString(_downloadsKey)).map(DownloadRecord.fromJson).whereType<DownloadRecord>());
    _bump();
  }

  static String _key(ContentItem item) => '${item.platformSlug}:${item.id}';
  static String downloadKey(ContentItem item, int episode, String quality) => '${item.platformSlug}:${item.id}:$episode:$quality';

  static bool isFavorite(ContentItem item) => _favorites.any((e) => e.id == item.id && e.platformSlug == item.platformSlug);
  static bool isDownloaded(ContentItem item, {int? episode}) => _downloads.any((e) => e.item.id == item.id && e.item.platformSlug == item.platformSlug && (episode == null || e.episode == episode));

  static int continueEpisode(ContentItem item) => _progress[_key(item)]?.episode ?? int.tryParse(item.chapterId) ?? 1;
  static WatchProgress? progressFor(ContentItem item) => _progress[_key(item)];

  static Future<void> saveProgress(ContentItem item, int episode, Duration position, Duration duration) async {
    if (episode <= 0) return;
    debugPrint('LIVEGO_PLAYER event=player_progress_saved platform=${item.platformSlug} content=${item.id} episode=$episode positionMs=${position.inMilliseconds} durationMs=${duration.inMilliseconds}');
    _progress[_key(item)] = WatchProgress(item: item, episode: episode, position: position, duration: duration, updatedAt: DateTime.now());
    addHistory(item, notify: false);
    await _persistProgress();
    _bump();
  }

  static Future<void> markEpisodeComplete(ContentItem item, int episode) async {
    final next = episode + 1;
    _progress[_key(item)] = WatchProgress(item: item, episode: next, position: Duration.zero, duration: Duration.zero, updatedAt: DateTime.now());
    addHistory(item, notify: false);
    await _persistProgress();
    _bump();
  }

  static void addHistory(ContentItem item, {bool notify = true}) {
    _history.removeWhere((e) => e.id == item.id && e.platformSlug == item.platformSlug);
    _history.insert(0, item);
    if (_history.length > 80) _history.removeRange(80, _history.length);
    _persistHistory();
    if (notify) _bump();
  }

  static Future<void> toggleFavorite(ContentItem item) async {
    final index = _favorites.indexWhere((e) => e.id == item.id && e.platformSlug == item.platformSlug);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.insert(0, item);
    }
    await _persistFavorites();
    _bump();
  }

  static Future<void> addOrUpdateDownload(DownloadRecord record) async {
    final index = _downloads.indexWhere((e) => e.key == record.key);
    if (index >= 0) {
      _downloads[index] = record;
    } else {
      _downloads.insert(0, record);
    }
    await _persistDownloads();
    _bump();
  }

  static Future<void> removeDownload(DownloadRecord record) async {
    _downloads.removeWhere((e) => e.key == record.key);
    await _persistDownloads();
    _bump();
  }

  static Future<void> clearDownloads() async {
    _downloads.clear();
    await _persistDownloads();
    _bump();
  }

  static Future<void> clearHistory() async {
    _history.clear();
    _progress.clear();
    await _persistHistory();
    await _persistProgress();
    _bump();
  }

  static Future<void> clearFavorites() async {
    _favorites.clear();
    await _persistFavorites();
    _bump();
  }

  /// User-data destructive reset only. Cache maintenance must not call this.
  static Future<void> clearAll() async {
    _history.clear();
    _favorites.clear();
    _downloads.clear();
    _progress.clear();
    await _persistHistory();
    await _persistFavorites();
    await _persistDownloads();
    await _persistProgress();
    _bump();
  }


  static Future<void> saveSettings() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final payload = <String, dynamic>{
      'language': LiveGoSettings.language,
      'defaultPlatform': LiveGoSettings.defaultPlatform,
      'quality': LiveGoSettings.quality,
      'layoutMode': LiveGoSettings.layoutModeForPersistence(),
      'drmMode': LiveGoSettings.drmMode,
      'subtitlesEnabled': LiveGoSettings.subtitlesEnabled,
      'autoNextEnabled': LiveGoSettings.autoNextEnabled,
      'downloadWifiOnly': LiveGoSettings.downloadWifiOnly,
      'lowEndTvMode': LiveGoSettings.lowEndTvMode,
      'backgroundPoster': LiveGoSettings.backgroundPoster,
      'cachePlayback': LiveGoSettings.cachePlayback,
      'manualRotateButton': LiveGoSettings.manualRotateButton,
      'tvPlayerEngineOverride': LiveGoSettings.tvPlayerEngineOverride,
      'tvSourceSetupCompleted': LiveGoSettings.tvSourceSetupCompleted,
      'mobileHomeGrid': LiveGoSettings.mobileHomeGrid,
      'tvHomeGrid': LiveGoSettings.tvHomeGrid,
      'activePlatforms': LiveGoSettings.activePlatforms.toList(),
      'homePlatforms': LiveGoSettings.homePlatforms.toList(),
      'platformLanguages': LiveGoSettings.platformLanguages,
      'homeCategories': LiveGoSettings.homeCategories,
      'tvLastHomeCategories': LiveGoSettings.tvLastHomeCategories,
    };
    await prefs.setString(_settingsKey, jsonEncode(payload));
    _bump();
  }

  static Future<void> clearSavedSettings() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.remove(_settingsKey);
    LiveGoSettings.reset();
    LiveGoSettings.applyRuntimeLayoutGuard(isTvRuntime: LiveGoSettings.runtimeLockedToTv);
    _bump();
  }

  static void _loadSettings() {
    final raw = _prefs?.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      final supported = LiveGoSettings.supportedPlatforms.toSet();

      LiveGoSettings.language = _string(json['language'], LiveGoSettings.language);
      LiveGoSettings.quality = _string(json['quality'], LiveGoSettings.quality);
      final savedLayout = _string(json['layoutMode'], LiveGoSettings.layoutMode);
      LiveGoSettings.layoutMode = LiveGoSettings.normalizeLayoutMode(savedLayout);
      LiveGoSettings.applyRuntimeLayoutGuard(isTvRuntime: LiveGoSettings.runtimeLockedToTv);
      LiveGoSettings.drmMode = _string(json['drmMode'], LiveGoSettings.drmMode);
      LiveGoSettings.subtitlesEnabled = _bool(json['subtitlesEnabled'], LiveGoSettings.subtitlesEnabled);
      LiveGoSettings.autoNextEnabled = _bool(json['autoNextEnabled'], LiveGoSettings.autoNextEnabled);
      LiveGoSettings.downloadWifiOnly = _bool(json['downloadWifiOnly'], LiveGoSettings.downloadWifiOnly);
      LiveGoSettings.lowEndTvMode = _bool(json['lowEndTvMode'], LiveGoSettings.lowEndTvMode);
      LiveGoSettings.backgroundPoster = _bool(json['backgroundPoster'], LiveGoSettings.backgroundPoster);
      LiveGoSettings.cachePlayback = _bool(json['cachePlayback'], LiveGoSettings.cachePlayback);
      LiveGoSettings.manualRotateButton = _bool(json['manualRotateButton'], LiveGoSettings.manualRotateButton);
      LiveGoSettings.tvPlayerEngineOverride = _string(json['tvPlayerEngineOverride'], LiveGoSettings.tvPlayerEngineOverride);
      LiveGoSettings.tvSourceSetupCompleted = _bool(json['tvSourceSetupCompleted'], LiveGoSettings.tvSourceSetupCompleted);
      // Grid settings are now fixed: HP=3, TV=7.
      // Ignore stale saved values so old settings cannot break layout.
      LiveGoSettings.mobileHomeGrid = 3;
      LiveGoSettings.tvHomeGrid = 7;

      final savedActivePlatforms = _stringList(json['activePlatforms']);
      final savedHomePlatforms = _stringList(json['homePlatforms']);
      var active = _dedupeSupported(savedActivePlatforms, supported);
      var home = _dedupeSupported(savedHomePlatforms, supported);
      final hasLegacyApiSource = savedActivePlatforms.any(_isLegacyApiSource) ||
          savedHomePlatforms.any(_isLegacyApiSource) ||
          _isLegacyApiSource(json['defaultPlatform']);

      // Kalau setting lama masih berisi Anichin-style source, reset ke Nobuzero clean starter.
      // Ini mencegah Home/Source Manager campur engine lama dengan Nobuzero aktif.
      if (hasLegacyApiSource && active.length < 2) {
        active = List<String>.from(LiveGoSettings.defaultPlatforms);
      }
      if (hasLegacyApiSource && home.length < 2) {
        home = List<String>.from(LiveGoSettings.defaultPlatforms);
      }

      // Nobuzero migration guard:
      // Old saved source settings can leave Home with only one Nobuzero platform
      // (or a legacy alias normalized to freereels). Always merge the
      // current Nobuzero starter pack back into active/home so Source Manager and
      // Home expose all clean Nobuzero platforms after update.
      final defaultNobuzeroPlatforms = LiveGoSettings.defaultPlatforms
          .where(supported.contains)
          .toList(growable: false);
      if (defaultNobuzeroPlatforms.isNotEmpty) {
        for (final slug in defaultNobuzeroPlatforms) {
          if (!active.contains(slug)) active.add(slug);
          if (!home.contains(slug)) home.add(slug);
        }
      }

      if (active.isNotEmpty) {
        LiveGoSettings.activePlatforms
          ..clear()
          ..addAll(active);
      }
      if (home.isNotEmpty) {
        LiveGoSettings.homePlatforms
          ..clear()
          ..addAll(home.where(LiveGoSettings.activePlatforms.contains).take(6));
      }
      if (LiveGoSettings.homePlatforms.isEmpty) {
        LiveGoSettings.homePlatforms.add(LiveGoSettings.activePlatforms.isNotEmpty
            ? LiveGoSettings.activePlatforms.first
            : LiveGoSettings.defaultPlatforms.first);
      }

      final savedDefault = _normalizeSavedPlatform(_string(json['defaultPlatform'], LiveGoSettings.homePlatforms.first));
      LiveGoSettings.defaultPlatform = LiveGoSettings.activePlatforms.contains(savedDefault)
          ? savedDefault
          : LiveGoSettings.homePlatforms.first;

      final languages = json['platformLanguages'];
      if (languages is Map) {
        for (final entry in languages.entries) {
          final slug = _normalizeSavedPlatform(entry.key);
          if (supported.contains(slug)) {
            LiveGoSettings.setLanguageForPlatform(slug, '${entry.value}');
          }
        }
      }

      final categories = json['homeCategories'];
      if (categories is Map) {
        for (final entry in categories.entries) {
          final slug = _normalizeSavedPlatform(entry.key);
          if (!supported.contains(slug)) continue;
          LiveGoSettings.setCategoriesFor(slug, _stringList(entry.value));
        }
      }

      final tvLastCategories = json['tvLastHomeCategories'];
      if (tvLastCategories is Map) {
        LiveGoSettings.tvLastHomeCategories.clear();
        for (final entry in tvLastCategories.entries) {
          final slug = _normalizeSavedPlatform(entry.key);
          if (!supported.contains(slug)) continue;
          final max = LiveGoSettings.categoriesFor(slug).length - 1;
          if (max < 0) continue;
          LiveGoSettings.tvLastHomeCategories[slug] = parseInt(entry.value, fallback: 0).clamp(0, max).toInt();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('LIVEGO SETTINGS LOAD ERROR: $e');
    }
  }

  static List<String> _dedupeSupported(List<String> values, Set<String> supported) {
    final out = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final slug = _normalizeSavedPlatform(value);
      if (!supported.contains(slug)) continue;
      if (seen.add(slug)) out.add(slug);
    }
    return out;
  }

  static bool _isLegacyApiSource(Object? value) {
    final slug = '${value ?? ''}'.trim().toLowerCase();
    return const <String>{
      'shortmax',
      'netshort',
      'pinedrama',
      'flickreels',
      'meloshort',
      'dramabox',
      'melolo',
    }.contains(slug);
  }

  static String _normalizeSavedPlatform(Object? value) {
    final slug = '${value ?? ''}'.trim().toLowerCase();
    if (_isLegacyApiSource(slug)) return 'freereels';
    return slug;
  }

  static String _string(Object? value, String fallback) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  static bool _bool(Object? value, bool fallback) {
    if (value is bool) return value;
    final text = '${value ?? ''}'.toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const <String>[];
  }

  static Map<String, dynamic> itemToJson(ContentItem item) => {
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

  static ContentItem itemFromJson(Map<String, dynamic> json) => ContentItem(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? 'Untitled'}',
        source: '${json['source'] ?? json['platformSlug'] ?? ''}',
        category: '${json['category'] ?? 'Drama'}',
        description: '${json['description'] ?? ''}',
        posterUrl: '${json['posterUrl'] ?? json['poster'] ?? json['cover'] ?? ''}',
        backdropUrl: '${json['backdropUrl'] ?? json['backdrop'] ?? json['posterUrl'] ?? ''}',
        rating: double.tryParse('${json['rating'] ?? '8.0'}') ?? 8.0,
        episodes: parseInt(json['episodes'], fallback: 1),
        updated: json['updated'] == true,
        platformSlug: '${json['platformSlug'] ?? 'shortmax'}',
        chapterId: '${json['chapterId'] ?? '1'}',
        lang: '${json['lang'] ?? 'id'}',
      );

  static int parseInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> _persistHistory() async => _prefs?.setString(_historyKey, jsonEncode(_history.map(itemToJson).toList()));
  static Future<void> _persistFavorites() async => _prefs?.setString(_favoritesKey, jsonEncode(_favorites.map(itemToJson).toList()));
  static Future<void> _persistProgress() async => _prefs?.setString(_progressKey, jsonEncode(_progress.values.map((e) => e.toJson()).toList()));
  static Future<void> _persistDownloads() async => _prefs?.setString(_downloadsKey, jsonEncode(_downloads.map((e) => e.toJson()).toList()));

  static void _bump() => version.value++;
}
