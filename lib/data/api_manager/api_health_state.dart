enum ApiHealthStatus {
  unknown,
  online,
  slow,
  offline,
  cooldown,
}

class ApiHealthEntry {
  final String platform;
  final ApiHealthStatus status;
  final int failures;
  final int lastLatencyMs;
  final DateTime updatedAt;
  final DateTime? cooldownUntil;
  final String? lastError;

  const ApiHealthEntry({
    required this.platform,
    required this.status,
    required this.failures,
    required this.lastLatencyMs,
    required this.updatedAt,
    this.cooldownUntil,
    this.lastError,
  });

  bool get isInCooldown {
    final until = cooldownUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  ApiHealthEntry copyWith({
    ApiHealthStatus? status,
    int? failures,
    int? lastLatencyMs,
    DateTime? updatedAt,
    DateTime? cooldownUntil,
    String? lastError,
    bool clearCooldown = false,
  }) {
    return ApiHealthEntry(
      platform: platform,
      status: status ?? this.status,
      failures: failures ?? this.failures,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      updatedAt: updatedAt ?? this.updatedAt,
      cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
      lastError: lastError ?? this.lastError,
    );
  }

  static ApiHealthEntry initial(String platform) {
    return ApiHealthEntry(
      platform: platform,
      status: ApiHealthStatus.unknown,
      failures: 0,
      lastLatencyMs: 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
