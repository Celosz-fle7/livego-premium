// Generated CinemaID seed catalog from playvibes local data

class CinemaIdSeedEntry {
  final String id;
  final String title;
  final String streamUrl;
  final String poster;
  final int duration;
  final int videoType;
  final List<String> categories;
  const CinemaIdSeedEntry({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.poster,
    required this.duration,
    required this.videoType,
    this.categories = const [],
  });
}

/// Ambil seed items yang relevan untuk suatu kategori tertentu.
/// Jika tidak ada kecocokan eksplisit, ambil deterministik slice agar kategori
/// tetap terisi film yang bervariasi dan tidak identik dengan tab lain.
List<CinemaIdSeedEntry> cinemaIdSeedsForCategory(String category) {
  final norm = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final matched = cinemaIdSeedCatalog.where((entry) {
    return entry.categories.any((c) {
      final cNorm = c.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return cNorm == norm || norm.contains(cNorm) || cNorm.contains(norm);
    });
  }).toList();

  if (matched.isNotEmpty) {
    return matched;
  }

  // Fallback subset deterministik berdasarkan hash nama kategori
  final offset = category.hashCode.abs() % cinemaIdSeedCatalog.length;
  final out = <CinemaIdSeedEntry>[];
  for (var i = 0; i < 8 && i < cinemaIdSeedCatalog.length; i++) {
    out.add(cinemaIdSeedCatalog[(offset + i) % cinemaIdSeedCatalog.length]);
  }
  return out;
}

const cinemaIdSeedCatalog = <CinemaIdSeedEntry>[
  CinemaIdSeedEntry(id: '507598858', title: 'Sweeties Take A Hike', streamUrl: 'http://movieph.xrrqe.com/vod/1/2024/06/12/4756af365d67/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20240612/234225fe902b.jpg', duration: 6951599, videoType: 1, categories: ['Trending Now', 'Prime Video', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '1276436835', title: 'Off Campus - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/05/13/a2aaace5f9dc/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260513/b733737a1477.jpg', duration: 3209250, videoType: 1, categories: ['Popular TV Shows', 'Prime Video', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '1702896696', title: 'Percy Jackson and the Olympians - Season 2', streamUrl: 'http://movieph.xrrqe.com/vod/2/2025/12/10/b6378e100290/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20251210/d97c05b9891e.jpg', duration: 2571208, videoType: 1, categories: ['Popular TV Shows', 'Disney', 'Crunchyroll', 'Trending Now']),
  CinemaIdSeedEntry(id: '713069235', title: 'Full House - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/11/12/76789367f207/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241112/4c8ba38de2ea.jpg', duration: 4226455, videoType: 1, categories: ['Popular TV Shows', 'MAX', 'Netflix']),
  CinemaIdSeedEntry(id: '917896393', title: 'Cycle of Sin - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/09/16/4f89dce66ec1/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260916/7ce2d9fa06ff.jpg', duration: 2787840, videoType: 1, categories: ['Popular TV Shows', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '805913273', title: 'Practical Magic', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/11/07/bce5b730c286/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241107/447ff6c0535f.jpg', duration: 6250120, videoType: 1, categories: ['Popular Movies', 'MAX', 'Apple TV+']),
  CinemaIdSeedEntry(id: '1060624796', title: 'Ted Lasso - Season 4', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/08/05/c8e579d215a7/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260805/2d9db5a331d7.jpg', duration: 2492615, videoType: 1, categories: ['Popular TV Shows', 'Apple TV+', 'Trending Now']),
  CinemaIdSeedEntry(id: '1430625617', title: 'A Returner\'s Magic Should Be Special - Season 2', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/10/08/0938fe0efa3c/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20261008/8562277ea833.jpg', duration: 1420168, videoType: 1, categories: ['Popular Anime', 'Crunchyroll', 'Trending Now']),
  CinemaIdSeedEntry(id: '1639694236', title: 'Hokum', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/10/10/9ed7b87f39e9/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20261010/d72561ca1a58.jpg', duration: 6435680, videoType: 1, categories: ['Popular Movies', 'Prime Video', 'AMC+', 'Trending Now']),
  CinemaIdSeedEntry(id: '1852371385', title: 'Toy Story 5', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/08/18/cb7db725a30b/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260619/3c9fcf94a737.jpg', duration: 6206833, videoType: 1, categories: ['Popular Movies', 'Disney', 'Popular Anime', 'Crunchyroll', 'Trending Now']),
  CinemaIdSeedEntry(id: '1412591741', title: 'Suddenly Satan', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/10/01/e6953d1e1704/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20261001/3dd4e21663ce.jpg', duration: 6784240, videoType: 1, categories: ['Popular Movies', 'Prime Video', 'Today\'s New Movies']),
  CinemaIdSeedEntry(id: '667739801', title: 'Paranormal Activity 4', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/18/38bb48774d1c/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241018/66e649844508.jpg', duration: 5177340, videoType: 1, categories: ['Popular Movies', 'Paramount+', 'Today\'s New Movies']),
  CinemaIdSeedEntry(id: '1259219598', title: 'Young Woman and the Sea', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/20/9cadfa5cf229/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241020/07522ca39e8c.jpg', duration: 7737333, videoType: 1, categories: ['Popular Movies', 'Disney', 'JUSTWATCH TOP 100']),
  CinemaIdSeedEntry(id: '1011718738', title: 'V/H/S/94', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/18/b6e0613c6962/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241018/de2c87391daa.jpg', duration: 6211138, videoType: 1, categories: ['Popular Movies', 'Paramount+', 'Today\'s New Movies']),
  CinemaIdSeedEntry(id: '1372657076', title: 'The Cabin in the Woods', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/18/80ae7004103f/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241018/dfef3600aa17.jpg', duration: 5698375, videoType: 1, categories: ['Popular Movies', 'Netflix', 'MAX', 'AMC+', 'JUSTWATCH TOP 100']),
  CinemaIdSeedEntry(id: '1172321970', title: '2012', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/18/b823fba86710/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241018/6ca155120ed9.jpg', duration: 9469795, videoType: 1, categories: ['Popular Movies', 'Netflix', 'JUSTWATCH TOP 100']),
  CinemaIdSeedEntry(id: '1810481730', title: 'Renovation Island: The Adventure Continues - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/10/11/fb9dbf72e3e7/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20261011/b2cab455325f.jpg', duration: 2581879, videoType: 1, categories: ['Popular TV Shows', 'Hulu', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '865405567', title: 'Teach You a Lesson - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/08/21/19a8f6dfacbd/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260605/900dd9766d99.jpg', duration: 3162952, videoType: 2, categories: ['Popular TV Shows', 'Rakuten Viki', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '66327880', title: 'Wajah Cinta Yang Lain - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/07/07/c9b5f88a3baa/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260707/b2e112d6bb06.jpg', duration: 3100640, videoType: 1, categories: ['Popular TV Shows', 'Indonesian Drama', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '986389248', title: 'Terikat Janji - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/04/14/3dc804128297/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260414/a19484eb848c.jpg', duration: 2477320, videoType: 1, categories: ['Popular TV Shows', 'Indonesian Drama', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '567540581', title: 'Shall We Dance - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/02/08/d5277c48831e/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260207/2d16440e5f93.jpg', duration: 879800, videoType: 1, categories: ['Popular TV Shows', 'New Korean drama series', 'Rakuten Viki']),
  CinemaIdSeedEntry(id: '750137859', title: 'The Secret of Us - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/16/e88274077073/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241016/342410313bcb.jpg', duration: 3048279, videoType: 1, categories: ['Popular TV Shows', 'New Korean drama series', 'Rakuten Viki', 'Hulu']),
  CinemaIdSeedEntry(id: '308771109', title: 'Monsters: The Lyle and Erik Menendez Story - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/26/d451117210ac/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241026/c332b29b6486.jpg', duration: 3475430, videoType: 1, categories: ['Popular TV Shows', 'Netflix', 'Trending Now', 'JUSTWATCH TOP 100']),
  CinemaIdSeedEntry(id: '1422217047', title: 'Sundutan', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/03/06/2a911e8803bd/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260306/6cc0df9ad5d8.jpg', duration: 4149133, videoType: 1, categories: ['Popular Movies', 'Today\'s New Movies']),
  CinemaIdSeedEntry(id: '1241363318', title: 'Aswang Sa Kamalig', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/03/27/d4df8eba8d6b/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260327/60578512504b.jpg', duration: 1049416, videoType: 1, categories: ['Popular Movies', 'Today\'s New Movies']),
  CinemaIdSeedEntry(id: '922174692', title: 'Cleopatra', streamUrl: 'http://movieph.xrrqe.com/vod/1/2024/06/12/0b74c4aa98f7/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20240612/e3628dd15154.jpg', duration: 6154099, videoType: 1, categories: ['Popular Movies', 'Disney', 'JUSTWATCH TOP 100']),
  CinemaIdSeedEntry(id: '1249240296', title: 'Mia Dek Ja Pa Wai Teen', streamUrl: 'http://movieph.xrrqe.com/vod/1/2023/12/12/0fa28802aa73/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20231211/f9788057813a.jpg', duration: 3216127, videoType: 1, categories: ['Popular Movies', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '2099860975', title: 'Village of Widows', streamUrl: 'http://movieph.xrrqe.com/vod/1/2024/04/13/289d93c93c67/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20240412/a568619dfa8d.jpg', duration: 4382966, videoType: 1, categories: ['Popular Movies', 'AMC+', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '620771202', title: 'The Japanese Wife Next Door', streamUrl: 'http://movieph.xrrqe.com/vod/1/2023/11/16/87b324f21586/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20231116/56cebb3f4d15.jpg', duration: 3619449, videoType: 1, categories: ['Popular Movies', 'New Korean drama series', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '779581788', title: 'MEYD-528-SUB [English Subtitle] Hypnotism Fertility NTR This Horny Housewife Is Cumming To The Rhythm Of Follow-Up Piston Pounding Thrusts And Shaking Her Ass And Begging For Another Man To Impregnate Her Rin Azuma', streamUrl: 'http://movieph.xrrqe.com/vod/1/2024/09/15/01fd2ab4da0f/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20240913/b26db5ad6c29.jpg', duration: 8834992, videoType: 1, categories: ['Popular Movies', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '1900560783', title: 'VRTM-345 “I Just Want To Touch Them Once!” A Naughty Big Brother Slips His Little Sister', streamUrl: 'http://movieph.xrrqe.com/vod/1/2024/10/11/ec0aebe22671/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241014/7bcd237ae21e.jpg', duration: 8959233, videoType: 1, categories: ['Popular Movies', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '1455868673', title: 'MIMK-180 Dokter Tobrut Cabul – Yoshine Yuria', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/11/05/c5759929d736/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241105/412f65fc772a.jpg', duration: 7106399, videoType: 1, categories: ['Popular Movies', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '271987015', title: 'National Sexuality Management Committee', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/11/03/ce5f08e28eb5/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241106/35855e8cee9d.jpg', duration: 4760766, videoType: 1, categories: ['Popular Movies', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '844961752', title: 'Scooby Doo: A XXX Parody', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/11/05/bba0e9dea45c/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241107/a287c8a39ff9.jpg', duration: 6795566, videoType: 1, categories: ['Popular Anime', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '737179739', title: 'Srigala Betina – Kelas Bintang', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/11/02/8452c2657991/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241104/40d43f1408b1.jpg', duration: 4005293, videoType: 1, categories: ['Popular Movies', 'Indonesian Drama', 'Today\'s New Streaming']),
  CinemaIdSeedEntry(id: '1638375442', title: 'Sex/Life - Season 2', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/25/5ad3388b345e/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241019/738295d563d7.jpg', duration: 3152316, videoType: 2, categories: ['Popular TV Shows', 'Netflix', 'Trending Now']),
  CinemaIdSeedEntry(id: '135442124', title: '18++: Forever Love', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/16/4a45db05b9d9/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241016/43439171ae88.jpg', duration: 4909337, videoType: 1, categories: ['Popular Movies', 'Today\'s New Movies']),
  CinemaIdSeedEntry(id: '32427991', title: 'Serigala Terakhir - Season 2', streamUrl: 'http://movieph.xrrqe.com/vod/2/2024/10/31/fe21fc41e267/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20241031/1e5158ea1b36.jpg', duration: 3226479, videoType: 1, categories: ['Popular TV Shows', 'Indonesian Drama', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '455229590', title: 'Supergirl', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/07/28/80e8cd7de0fa/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260627/b3633cfd233a.jpg', duration: 6405816, videoType: 1, categories: ['Popular Movies', 'MAX', 'Apple TV+']),
  CinemaIdSeedEntry(id: '1617731654', title: 'The Odyssey', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/07/20/c84f70b82a32/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260720/e6154aa964ba.jpg', duration: 9849041, videoType: 1, categories: ['Popular Movies', 'Apple TV+', 'JUSTWATCH TOP 100']),
  CinemaIdSeedEntry(id: '1202436160', title: 'Agak Laen: Menyala Pantiku!', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/05/28/eb3234b44b27/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260528/8a8ece80c14c.jpg', duration: 7168291, videoType: 1, categories: ['Popular Movies', 'Indonesian Drama', 'Trending Now', 'JUSTWATCH TOP 100']),
  CinemaIdSeedEntry(id: '1086220530', title: 'Another Self - Season 3', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/06/24/6ef3d7bb0d0f/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260624/16781068f0db.jpg', duration: 2588166, videoType: 1, categories: ['Popular TV Shows', 'Netflix', 'Today\'s New Series']),
  CinemaIdSeedEntry(id: '1729740208', title: 'Study Group - Season 1', streamUrl: 'http://movieph.xrrqe.com/vod/2/2025/01/24/20071e84dfcc/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20250126/48fcdc120d4f.jpg', duration: 2619683, videoType: 1, categories: ['Popular TV Shows', 'New Korean drama series', 'Rakuten Viki', 'Hulu']),
  CinemaIdSeedEntry(id: '514463823', title: 'Hayok', streamUrl: 'http://movieph.xrrqe.com/vod/2/2026/05/15/97eea817b52b/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20260515/413063908a3d.jpg', duration: 4470966, videoType: 1, categories: ['Popular Movies', 'Trending Now', 'Today\'s New Movies']),
  CinemaIdSeedEntry(id: '252064115', title: 'Mayor of Kingstown - Season 4', streamUrl: 'http://movieph.xrrqe.com/vod/2/2025/10/26/390bdb150e74/index5.m3u8', poster: 'https://movieph.xrrqe.com/img/vod_pic/20251026/8e6363e60918.jpg', duration: 3164458, videoType: 1, categories: ['Popular TV Shows', 'Paramount+', 'Today\'s New Series']),
];
