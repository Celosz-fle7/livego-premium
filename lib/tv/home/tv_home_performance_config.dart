/// Low-end Android TV performance contract for Home.
///
/// Home must behave like a thin server manifest: enough links/posters to start
/// watching quickly, but not a full catalog dump. Keep API/cache timings and
/// visible item limits here so UI, repository, and interaction code do not
/// drift into different performance budgets.
class TvHomePerformanceConfig {
  const TvHomePerformanceConfig._();

  /// Hard cap for one Home platform/category manifest after playable filtering.
  /// Disetel tipis (28 item / max 3-4 baris) agar TV low-end tidak OOM atau lemot.
  static const int maxManifestItems = 28;

  /// Keep the poster grid short on low-end STB devices.
  ///
  /// More rows should be fetched through category/platform changes or detail
  /// pages, not by making Home mount a large poster catalog at once.
  static const int maxVisibleGridRows = 3;

  /// Cached Home should appear almost immediately, then refresh in background.
  static const Duration cacheReadTimeout = Duration(milliseconds: 350);

  /// Foreground network load remains bounded so Home never waits too long on a
  /// slow source before falling back to cache/offline state.
  static const Duration foregroundNetworkTimeout = Duration(seconds: 5);

  /// Fallback cache gets a small second chance after network/source failure.
  static const Duration fallbackCacheTimeout = Duration(milliseconds: 500);

  /// Background refresh can be slightly longer because cached content is already
  /// visible and the user can keep navigating.
  static const Duration backgroundRefreshTimeout = Duration(seconds: 7);
}
