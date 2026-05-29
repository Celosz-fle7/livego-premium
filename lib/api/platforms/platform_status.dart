enum PlatformHealth {
  online,
  slow,
  offline,
}

extension PlatformHealthLabel on PlatformHealth {
  String get key {
    switch (this) {
      case PlatformHealth.online:
        return 'online';
      case PlatformHealth.slow:
        return 'slow';
      case PlatformHealth.offline:
        return 'offline';
    }
  }

  static PlatformHealth fromDurationAndRows(Duration duration, int rows) {
    if (rows <= 0) return PlatformHealth.offline;
    if (duration.inMilliseconds > 2500) return PlatformHealth.slow;
    return PlatformHealth.online;
  }
}
