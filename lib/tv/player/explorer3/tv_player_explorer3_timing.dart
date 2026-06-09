/// Timing/budget constants for TV Player Explorer3.
///
/// Keep these values outside the screen so player tuning does not require
/// touching UI, remote mapping, or playback state code.
class TvPlayerExplorer3Timing {
  const TvPlayerExplorer3Timing._();

  static const int maxEpisode = 999;
  static const int prefetchKeyLimit = 96;
  static const int defaultPrefetchCount = 2;

  static const int cursorMoveGuardMs = 90;
  static const int playerUiTickMs = 500;
  static const int progressSaveThrottleMs = 12000;

  static const Duration episodeWarmupDelay = Duration(seconds: 1);
  static const Duration lightPrefetchDelay = Duration(seconds: 10);
  static const Duration episodeResolveTimeout = Duration(seconds: 4);
  static const Duration nativeOpenTimeout = Duration(seconds: 4);
  static const Duration episodeWarmupTimeout = Duration(seconds: 5);
  static const Duration lightPrefetchTimeout = Duration(seconds: 7);
  static const Duration fallbackControllerInitTimeout = Duration(seconds: 22);
  static const Duration autoHideDelay = Duration(seconds: 5);
  static const Duration statusDelay = Duration(seconds: 2);

  static const int surfaceMaxChecks = 60;
  static const Duration surfaceCheckInterval = Duration(milliseconds: 100);
}
