class PlaybackTimeoutConfig {
  const PlaybackTimeoutConfig._();

  // Fast path: tembak /episode dulu supaya player tidak menunggu detail/allepisode.
  static const Duration directEpisode = Duration(seconds: 6);

  // Fallback normal: dipakai hanya kalau direct /episode gagal/kosong.
  static const Duration fallbackStream = Duration(seconds: 10);

  // Metadata tidak boleh menahan video pertama jalan.
  static const Duration detailBackground = Duration(seconds: 8);
  static const Duration episodeListBackground = Duration(seconds: 14);

  // Inisialisasi controller boleh sedikit lebih panjang karena ini sudah tahap load video.
  static const Duration controllerInit = Duration(seconds: 16);
  static const Duration subtitleFetch = Duration(seconds: 8);
}
