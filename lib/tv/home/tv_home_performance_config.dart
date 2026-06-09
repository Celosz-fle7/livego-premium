/// Low-end Android TV performance contract for Home.
///
/// Home must behave like a thin server manifest: enough links/posters to start
/// watching quickly, but not a full catalog dump. Keep API/cache timings and
/// visible item limits here so UI, repository, and interaction code do not
/// drift into different performance budgets.
class TvHomePerformanceConfig {
  const TvHomePerformanceConfig._();

  /// Hard cap for one Home platform/category manifest after playable filtering.
  static const int maxManifestItems = 30;

  /// Keep the poster grid short on low-end STB devices.
  ///
  /// More rows should be fetched through category/platform changes or detail
  /// pages, not by making Home mount a large poster catalog at once.
  static const int maxVisibleGridRows = 4;

  /// Cached Home should appear almost immediately, then refresh in background.
  static const Duration cacheReadTimeout = Duration(milliseconds: 520);

  /// Foreground network load remains bounded so Home never waits too long on a
  /// slow source before falling back to cache/offline state.
  static const Duration foregroundNetworkTimeout = Duration(seconds: 8);

  /// Fallback cache gets a small second chance after network/source failure.
  static const Duration fallbackCacheTimeout = Duration(milliseconds: 700);

  /// Background refresh can be slightly longer because cached content is already
  /// visible and the user can keep navigating.
  static const Duration backgroundRefreshTimeout = Duration(seconds: 10);

  /// Debounce platform/category changes so aggressive LEFT/RIGHT repeat does
  /// not fire a request per intermediate chip.
  static const Duration selectionCommitDelay = Duration(milliseconds: 180);
}
