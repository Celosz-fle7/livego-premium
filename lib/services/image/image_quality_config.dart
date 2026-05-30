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

  static const int minDecodeWidth = 240;
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
}
