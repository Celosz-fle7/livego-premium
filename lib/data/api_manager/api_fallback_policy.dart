class ApiFallbackPolicy {
  const ApiFallbackPolicy._();

  static const int maxFailureBeforeCooldown = 2;
  static const Duration cooldownBase = Duration(seconds: 45);
  static const Duration cooldownMax = Duration(minutes: 5);

  static Duration cooldownForFailures(int failures) {
    if (failures <= 0) return Duration.zero;
    final seconds = cooldownBase.inSeconds * failures;
    if (seconds > cooldownMax.inSeconds) return cooldownMax;
    return Duration(seconds: seconds);
  }

  static bool shouldTryNetwork({
    required bool cacheHit,
    required bool isCooldown,
    bool forceNetwork = false,
  }) {
    if (forceNetwork) return true;
    if (isCooldown && cacheHit) return false;
    return true;
  }
}
