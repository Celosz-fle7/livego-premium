class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  const CacheEntry({
    required this.data,
    required this.createdAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}
