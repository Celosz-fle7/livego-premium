enum LiveGoImageRole {
  poster,
  banner,
  detail,
  thumbnail,
}

class ImageQualityConfig {
  // Ubah angka di file ini saja kalau gambar terasa burik / terlalu berat.
  static const int posterWidth = 360;
  static const int tvPosterWidth = 280;
  static const int bannerWidth = 960;
  static const int tvBannerWidth = 860;
  static const int detailWidth = 640;
  static const int thumbnailWidth = 320;
  static const int tvThumbnailWidth = 220;

  // Tahap awal: decode/cache ringan dulu supaya list/grid cepat kelihatan.
  static const int posterLowWidth = 180;
  static const int tvPosterLowWidth = 150;
  static const int bannerLowWidth = 480;
  static const int tvBannerLowWidth = 420;
  static const int detailLowWidth = 320;
  static const int thumbnailLowWidth = 180;
  static const int tvThumbnailLowWidth = 140;

  static const int minDecodeWidth = 160;
  static const int maxDecodeWidth = 960;

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
        return tv ? tvThumbnailWidth : thumbnailWidth;
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
        return tv ? tvThumbnailLowWidth : thumbnailLowWidth;
    }
  }

  static int progressiveDelayMsFor(LiveGoImageRole role) {
    switch (role) {
      case LiveGoImageRole.poster:
        return 760;
      case LiveGoImageRole.banner:
        return 650;
      case LiveGoImageRole.detail:
        return 480;
      case LiveGoImageRole.thumbnail:
        return 360;
    }
  }

  static int tvProgressiveJitterMsFor(LiveGoImageRole role) {
    switch (role) {
      case LiveGoImageRole.poster:
        return 720;
      case LiveGoImageRole.banner:
        return 240;
      case LiveGoImageRole.detail:
        return 180;
      case LiveGoImageRole.thumbnail:
        return 320;
    }
  }
}
