/// Stable TV navigation indexes used by the shell and account shortcuts.
///
/// Keep indexes centralized so changing the rail order does not silently break
/// route restore/back behavior.
class TvNavIndex {
  const TvNavIndex._();

  static const int home = 0;
  static const int download = 1;
  static const int history = 2;
  static const int favorite = 3;
  static const int account = 4;
  static const int search = 5;
}
