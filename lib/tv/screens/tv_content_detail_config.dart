import '../focus/tv_reachability.dart';

/// Detail screen constants.
///
/// Keep layout, episode-grid, and player handoff tuning outside the screen so
/// final polishing does not touch player/API/detail provider logic.
class TvContentDetailConfig {
  const TvContentDetailConfig._();

  static const Duration playerHandoffDelay = Duration(milliseconds: 16);

  static const double playFocusAlignment = 0.18;
  static const double backFocusAlignment = 0.06;

  static const int maxEpisodeChips = 80;
  static const int episodeGridStep = 6;
  static const int maxPlayerReturnAttempts = 3;

  static const List<Duration> playerReturnRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 50),
    Duration(milliseconds: 150),
    Duration(milliseconds: 300),
  ];

  static const double horizontalPadding = 44;
  static const double topPadding = 24;
  static const double bottomPadding = TvReachability.contentBottomPadding;
  static const double backButtonSize = 48;
  static const double backButtonRadius = 16;
  static const double backRowGap = 14;
  static const double headerToContentGap = 18;
  static const double posterWidth = 204;
  static const double posterHeight = 306;
  static const double posterRadius = 22;
  static const double posterToInfoGap = 24;
  static const double titleFontSize = 32;
  static const double titleToPillGap = 12;
  static const double degradedNoticeGap = 14;
  static const double descriptionGap = 16;
  static const double actionGap = 22;
  static const double actionButtonGap = 14;
  static const double episodeSectionGap = 24;
  static const double episodeTitleGap = 10;
  static const double episodeGridGap = 12;
  static const double episodeChipSpacing = 10;
  static const double episodeChipRunSpacing = 10;

  static const double actionButtonHeight = 50;
  static const double actionButtonMinWidth = 148;
  static const double actionButtonHorizontalPadding = 22;

  static const double episodeChipWidth = 124;
  static const double episodeChipHeight = 52;
  static const double episodeChipRadius = 16;

  static const String pageLabel = 'Detail Konten';
  static const String emptyDescription = 'Deskripsi belum tersedia dari API.';
  static const String degradedText =
      'Detail lengkap/episode sedang lambat. Data dasar tetap bisa dipakai, Play masih bisa dicoba.';
  static const String episodeFallbackText =
      'Episode list belum tersedia. Tekan Play untuk lanjut dari episode tersimpan, atau Coba Detail untuk refresh.';
}
