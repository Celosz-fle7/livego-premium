import '../../services/api/api_backend.dart';
import '../../services/api/api_platform.dart';

class ApiCapabilityLock {
  const ApiCapabilityLock._();

  static List<String> badgesFor(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final badges = <String>[
      _backendBadge(config.backend),
      _videoBadge(config.videoType),
    ];

    if (config.supportsSubtitle) badges.add('SUB');
    if (config.streamFromAllEpisodes) badges.add('ALL-EP');
    if (config.isEncrypted) badges.add('DRM');
    if (_isBeta(config)) badges.add('BETA');

    return badges;
  }

  static String dashboardSubtitleFor(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    final parts = <String>[
      config.backend.label,
      _videoLabel(config.videoType),
      'Endpoint: ${config.apiSlug}',
    ];

    if (config.supportsSubtitle) parts.add('subtitle');
    if (config.streamFromAllEpisodes) parts.add('stream dari allepisode');
    if (config.isEncrypted) parts.add('encrypted belum native');

    return parts.join(' • ');
  }

  static String warningFor(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    if (config.isEncrypted) {
      return 'DRM/CENC: jangan dipaksa ke native player sampai decrypt/audio siap.';
    }
    if (config.isNobuzero) {
      return 'Nobuzero beta: aktifkan seperlunya, cocok sebagai fallback.';
    }
    if (config.streamFromAllEpisodes) {
      return 'Video bisa lebih stabil dari /allepisode, bukan cuma /episode.';
    }
    return '';
  }

  static bool isSafeForDefaultHome(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    return config.enabledByDefault && !config.isEncrypted;
  }

  static String _backendBadge(LiveGoApiBackend backend) {
    switch (backend) {
      case LiveGoApiBackend.anichin:
        return 'ANICHIN';
      case LiveGoApiBackend.nobuzero:
        return 'DOBDA';
    }
  }

  static String _videoBadge(LiveGoVideoType type) {
    switch (type) {
      case LiveGoVideoType.mp4:
        return 'MP4';
      case LiveGoVideoType.hls:
        return 'HLS';
      case LiveGoVideoType.encrypted:
        return 'DRM';
    }
  }

  static String _videoLabel(LiveGoVideoType type) {
    switch (type) {
      case LiveGoVideoType.mp4:
        return 'MP4 native';
      case LiveGoVideoType.hls:
        return 'HLS';
      case LiveGoVideoType.encrypted:
        return 'Encrypted';
    }
  }

  static bool _isBeta(LiveGoApiPlatform config) {
    return config.isNobuzero || config.isEncrypted;
  }
}
