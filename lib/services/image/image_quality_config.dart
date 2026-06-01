enum LiveGoImageRole {
  poster,
  banner,
  detail,
  thumbnail,
}

class ImageQualityConfig {
  // Ubah angka di file ini saja kalau gambar terasa burik / terlalu berat.
  static const int posterWidth = 360;
  static const int tvPosterWidth = 460;
  static const int bannerWidth = 960;
  static const int tvBannerWidth = 1280;
  static const int detailWidth = 720;
  static const int thumbnailWidth = 640;

  // Tahap awal: decode/cache ringan dulu supaya list/grid cepat kelihatan.
  static const int posterLowWidth = 180;
  static const int tvPosterLowWidth = 220;
  static const int bannerLowWidth = 480;
  static const int tvBannerLowWidth = 640;
  static const int detailLowWidth = 360;
  static const int thumbnailLowWidth = 240;

  static const int minDecodeWidth = 160;
  static const int maxDecodeWidth = 1280;

  static int widthFor({
    required LiveGoImageRole role,
    required bool tv,
    int? fallbackWidth,
  }) {
    switch (role) {
      case LiveGoImageRole.poster:
        return tv ? tvPosterWidth : posterWidth;
      case LiveGoImageRole.banner:
        return tv ? tvBannerWidth : bannerWidth;
      case LiveGoImageRole.detail:
        return detailWidth;
      case LiveGoImageRole.thumbnail:
        return thumbnailWidth;
    }
  }

  static int lowWidthFor({
    required LiveGoImageRole role,
    required bool tv,
  }) {
    switch (role) {
      case LiveGoImageRole.poster:
        return tv ? tvPosterLowWidth : posterLowWidth;
      case LiveGoImageRole.banner:
        return tv ? tvBannerLowWidth : bannerLowWidth;
      case LiveGoImageRole.detail:
        return detailLowWidth;
      case LiveGoImageRole.thumbnail:
        return thumbnailLowWidth;
    }
  }

  static int progressiveDelayMsFor(LiveGoImageRole role) {
    switch (role) {
      case LiveGoImageRole.poster:
        return 260;
      case LiveGoImageRole.banner:
        return 420;
      case LiveGoImageRole.detail:
        return 320;
      case LiveGoImageRole.thumbnail:
        return 220;
    }
  }
}
