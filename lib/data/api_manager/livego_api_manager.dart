import 'dart:async';

import '../../core/livego_settings.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../../services/content/content_health_service.dart';
import 'api_fallback_policy.dart';
import 'api_health_state.dart';
import 'api_request_queue.dart';
import 'api_result.dart';
import 'api_timeout_policy.dart';
import 'api_provider_contract.dart';
import 'api_provider_registry.dart';

class LiveGoApiManager {
  const LiveGoApiManager._();

  static final ApiRequestQueue _queue = ApiRequestQueue(maxParallel: 3);
  static final Map<String, ApiHealthEntry> _health = <String, ApiHealthEntry>{};

  static ApiHealthEntry healthOf(String platform) {
    final slug = _normalizePlatform(platform);
    return _health[slug] ?? ApiHealthEntry.initial(slug);
  }

  static bool isInCooldown(String platform) => healthOf(platform).isInCooldown;

  static List<String> fallbackPlatformsFor(String platform, {int max = 4}) {
    // Kept here as a public hook for UI/service diagnostics.
    final clean = _normalizePlatform(platform);
    final active = LiveGoSettings.activePlatforms
        .where((slug) => _normalizePlatform(slug) != clean)
        .where((slug) => !isInCooldown(slug))
        .take(max)
        .toList(growable: false);
    return active;
  }

  static bool supportsFeature(String platform, ApiProviderFeature feature) {
    return LiveGoApiProviderRegistry.supports(platform, feature);
  }

  static List<String> capabilityBadgesFor(String platform) {
    return LiveGoApiProviderRegistry.capabilityBadgesFor(platform);
  }

  static String statusFor(String platform) {
    final entry = healthOf(platform);
    if (entry.isInCooldown) return 'cooldown';
    switch (entry.status) {
      case ApiHealthStatus.online:
        return 'online';
      case ApiHealthStatus.slow:
        return 'slow';
      case ApiHealthStatus.offline:
        return 'offline';
      case ApiHealthStatus.cooldown:
        return 'cooldown';
      case ApiHealthStatus.unknown:
        return LiveGoSettings.statusFor(_normalizePlatform(platform));
    }
  }

  static Future<List<ContentItem>> fetchItems({
    required String platform,
    required String operation,
    required Future<List<ContentItem>> Function() request,
    Duration timeout = ApiTimeoutPolicy.home,
    List<ContentItem> fallback = const <ContentItem>[],
    bool forceNetwork = false,
  }) async {
    final result = await guard<List<ContentItem>>(
      platform: platform,
      operation: operation,
      timeout: timeout,
      fallback: fallback,
      forceNetwork: forceNetwork,
      request: () async => ContentHealthService.filterPlayable(await request()),
    );
    return ContentHealthService.filterPlayable(result.data ?? fallback);
  }

  static Future<ContentItem?> fetchDetail({
    required ContentItem item,
    required Future<ContentItem?> Function() request,
    ContentItem? fallback,
  }) async {
    final result = await guard<ContentItem?>(
      platform: item.platformSlug,
      operation: 'detail',
      timeout: ApiTimeoutPolicy.detail,
      fallback: fallback ?? item,
      request: request,
    );
    return result.data ?? fallback ?? item;
  }

  static Future<List<LiveGoEpisode>> fetchEpisodes({
    required ContentItem item,
    required Future<List<LiveGoEpisode>> Function() request,
    List<LiveGoEpisode> fallback = const <LiveGoEpisode>[],
  }) async {
    final result = await guard<List<LiveGoEpisode>>(
      platform: item.platformSlug,
      operation: 'episodes',
      timeout: ApiTimeoutPolicy.episodes,
      fallback: fallback,
      request: request,
    );
    return result.data ?? fallback;
  }

  static Future<StreamInfo> fetchStreamInfo({
    required ContentItem item,
    required Future<StreamInfo> Function() request,
    StreamInfo fallback = StreamInfo.empty,
    Duration timeout = ApiTimeoutPolicy.video,
  }) async {
    final result = await guard<StreamInfo>(
      platform: item.platformSlug,
      operation: 'video',
      timeout: timeout,
      fallback: fallback,
      forceNetwork: true,
      request: request,
    );
    return result.data ?? fallback;
  }

  static Future<String> runStatus({
    required String platform,
    required String operation,
    required Future<String> Function() request,
    Duration timeout = ApiTimeoutPolicy.ping,
    String fallbackStatus = 'offline',
  }) async {
    final result = await guard<String>(
      platform: platform,
      operation: operation,
      timeout: timeout,
      fallback: fallbackStatus,
      forceNetwork: true,
      request: request,
    );
    final status = result.data ?? fallbackStatus;
    LiveGoSettings.setPlatformStatus(_normalizePlatform(platform), status == 'cooldown' ? 'slow' : status);
    return status;
  }

  static Future<ApiResult<T>> guard<T>({
    required String platform,
    required String operation,
    required Future<T> Function() request,
    required Duration timeout,
    T? fallback,
    bool forceNetwork = false,
  }) async {
    final slug = _normalizePlatform(platform);
    final entry = healthOf(slug);

    if (!ApiFallbackPolicy.shouldTryNetwork(
      cacheHit: fallback != null,
      isCooldown: entry.isInCooldown,
      forceNetwork: forceNetwork,
    )) {
      _markCooldown(slug, entry, operation, 'cooldown active');
      return ApiResult<T>.success(fallback, fromFallback: true);
    }

    final started = DateTime.now();
    try {
      final data = await _queue.schedule<T>(() => request().timeout(timeout));
      final latencyMs = DateTime.now().difference(started).inMilliseconds;
      _markSuccess(slug, latencyMs);
      return ApiResult<T>.success(data);
    } catch (error, stackTrace) {
      _markFailure(slug, operation, error);
      if (fallback != null) {
        return ApiResult<T>.success(fallback, fromFallback: true);
      }
      return ApiResult<T>.failure(error, stackTrace: stackTrace);
    }
  }

  static void _markSuccess(String platform, int latencyMs) {
    final status = latencyMs > 2500 ? ApiHealthStatus.slow : ApiHealthStatus.online;
    _health[platform] = ApiHealthEntry(
      platform: platform,
      status: status,
      failures: 0,
      lastLatencyMs: latencyMs,
      updatedAt: DateTime.now(),
    );
    LiveGoSettings.setPlatformStatus(platform, status == ApiHealthStatus.slow ? 'slow' : 'online');
  }

  static void _markFailure(String platform, String operation, Object error) {
    final current = healthOf(platform);
    final failures = current.failures + 1;
    final shouldCooldown = failures >= ApiFallbackPolicy.maxFailureBeforeCooldown;
    final cooldown = shouldCooldown ? ApiFallbackPolicy.cooldownForFailures(failures) : Duration.zero;
    final status = shouldCooldown ? ApiHealthStatus.cooldown : ApiHealthStatus.offline;
    final now = DateTime.now();

    _health[platform] = current.copyWith(
      status: status,
      failures: failures,
      updatedAt: now,
      cooldownUntil: shouldCooldown ? now.add(cooldown) : null,
      lastError: '$operation: $error',
    );

    LiveGoSettings.setPlatformStatus(platform, shouldCooldown ? 'slow' : 'offline');
    // Keep this print small. It is useful in GitHub logs and Termux.
    print('LIVEGO API FAIL [$platform/$operation] failures=$failures cooldown=${shouldCooldown ? cooldown.inSeconds : 0}s error=$error');
  }

  static void _markCooldown(String platform, ApiHealthEntry entry, String operation, String reason) {
    _health[platform] = entry.copyWith(
      status: ApiHealthStatus.cooldown,
      updatedAt: DateTime.now(),
      lastError: '$operation: $reason',
    );
    LiveGoSettings.setPlatformStatus(platform, 'slow');
  }

  static String _normalizePlatform(String value) {
    final clean = value.trim().toLowerCase();
    return clean.isEmpty ? 'nobuzero_freereels' : clean;
  }
}
