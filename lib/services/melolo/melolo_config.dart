/// Konfigurasi statis Melolo (com.worldance.drama v5.3.7, infrastruktur ByteDance).
///
/// Hasil static teardown 2026-10-07 (114 endpoint, sensus anotasi dex):
/// - Host: https://api.tmtreader.com (utama), https://api-my.tmtreader.com (MY)
/// - Semua request API bawa param TT standar: aid, did, iid, device_id,
///   app_name, version_code, dsb.
/// - aid=645713 TERKONFIRMASI dari dex (deep-link scheme worldance645713://
///   dan param app_id=645713 ke api.tmtreader.com).
/// - Signing X-Argus/X-Gorgon/X-Ladon (libtobEmbedPagEncrypt.so, native)
///   TIDAK bisa direplika dari static — request dikirim tanpa header sign;
///   endpoint publik kemungkinan tetap menjawab (perlu 1 capture runtime
///   untuk konfirmasi, lihat ~/workspace/apkanalysis/melolo-protocol.md).
/// - Struktur respons video_detail/video_model BELUM terverifikasi live;
///   client memakai banyak fallback key (pola sama seperti CinemaID).
class MeloloConfig {
  MeloloConfig._();

  static const primaryHost = 'https://api.tmtreader.com';
  static const regionalHost = 'https://api-my.tmtreader.com';

  /// App ID ByteDance Melolo — confirmed dari dex (bukan 1371 milik Pangle).
  static const aid = '645713';
  static const appName = 'melolo';

  /// version_code tinggi agar tidak ditolak sebagai client jadul.
  static const versionCode = '999999999';

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 13; CPH2205 Build/TKQ1.221114.001) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  static const timeout = Duration(seconds: 15);

  /// Key SharedPreferences untuk did/iid persisten.
  static const deviceIdPrefKey = 'melolo_device_id';
  static const installIdPrefKey = 'melolo_install_id';

  // ---- Endpoint (hasil sensus dex) ----
  static const deviceRegisterPath =
      'https://log.byteoversea.com/service/2/device_register/';
  static const tabPath = '/i18n_novel/bookmall/tab/v1/';
  static const cellChangePath = '/i18n_novel/bookmall/cell/change/v1/';
  static const homepagePath = '/i18n_novel/userapi/get_homepage/v1/';
  static const searchPagePath = '/i18n_novel/search/page/v1/';
  static const searchSuggestPath = '/i18n_novel/search/suggest/v1/';
  static const videoDetailPath = '/novel/player/video_detail/v1/';
  static const videoModelPath = '/novel/player/video_model/v1/';
  static const multiVideoDetailPath = '/novel/player/multi_video_detail/v1/';
  static const multiVideoModelPath = '/novel/player/multi_video_model/v1/';

  /// Kategori sinkron (tanpa network). Nama tab aktual diambil dari
  /// /i18n_novel/bookmall/tab/v1/ dan dicocokkan di homeByCategory.
  static const categories = <String>[
    'For You',
    'Drama',
    'Romance',
    'Thriller',
    'Comedy',
  ];
}
