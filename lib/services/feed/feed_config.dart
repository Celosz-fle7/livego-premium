class FeedConfig {
  FeedConfig._();

  /// Jumlah item mentah yang disimpan dari API per platform + kategori.
  /// Provider API biasanya sudah punya mapping sendiri; LiveGo cukup tahan cadangan kecil.
  static const int rawItemsPerCategory = 50;

  /// Jumlah item yang ditampilkan di TV Home per kategori.
  static const int itemsPerCategory = 30;

  /// Kalau user aktif melihat platform/kategori yang sama, jangan refresh terlalu sering.
  /// Ini menjaga request API tetap hemat dan sinkron dengan konsep Home + LiveGo.
  static const Duration activeRefreshInterval = Duration(hours: 6);

  /// Cache keras tetap lebih lama supaya app tidak kosong/offline kalau API lambat.
  static const Duration hardHomeCacheTtl = Duration(hours: 12);

  /// Saat user balik ke kategori yang sama, urutan cache diacak ringan supaya terasa fresh
  /// tanpa request ulang.
  static const bool shuffleOnReturn = true;
}
