class FeedConfig {
  FeedConfig._();

  /// Jumlah item yang ditampilkan/disimpan per platform + kategori.
  /// Ubah angka ini kalau suatu saat mau 20, 30, 40, dst.
  static const int itemsPerCategory = 30;

  /// Kalau user aktif melihat platform/kategori yang sama, refresh data baru tiap 1 jam.
  /// Platform/kategori yang tidak dibuka tidak akan direfresh.
  static const Duration activeRefreshInterval = Duration(hours: 1);

  /// Cache keras tetap lebih lama supaya app tidak kosong/offline kalau API lambat.
  static const Duration hardHomeCacheTtl = Duration(hours: 4);

  /// Saat user balik ke kategori yang sama, urutan cache diacak ringan supaya terasa fresh
  /// tanpa request ulang.
  static const bool shuffleOnReturn = true;
}
