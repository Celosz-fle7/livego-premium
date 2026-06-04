class ApiTimeoutPolicy {
  const ApiTimeoutPolicy._();

  static const Duration ping = Duration(seconds: 4);
  static const Duration home = Duration(seconds: 10);
  static const Duration collection = Duration(seconds: 11);
  static const Duration search = Duration(seconds: 12);
  static const Duration detail = Duration(seconds: 14);
  static const Duration episodes = Duration(seconds: 18);
  static const Duration video = Duration(seconds: 12);
}
