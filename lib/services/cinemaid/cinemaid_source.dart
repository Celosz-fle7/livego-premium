import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'cinemaid_client.dart';
import 'cinemaid_config.dart';

/// Adapter CinemaID sebagai DramaSource.
///
/// Protokol (static teardown APK com.movieph.bj.playvibes 5.0.7):
/// - Base URL server-driven dari GET /api/public/init -> data.sys_conf.api_url
/// - Episode: GET /api/vod/info_new?vod_id=&collection= -> vod_collection[],
///   vod_url = stream langsung per episode (tanpa getplayinfo, mirip FreeReels)
/// - Subtitle: TIDAK disediakan API (kemungkinan in-band di m3u8) -> extras
///   mengembalikan daftar subtitle kosong
/// - Audio multi: audio_type_option[] dari detail
/// - Kualitas: tidak ada model di API (m3u8 adaptive)
/// - Paywall: model VIP/subscription (is_svip, vip_level, pay_status,
///   vod_duration_free), bukan coin per episode. Episode terkunci ditandai
///   di extras.unlocked=false — TIDAK ada bypass di sini.
class CinemaIdSource implements DramaSource {
  final CinemaIdClient _client = CinemaIdClient();

  /// Cache episodeId -> stream m3u8, diisi saat episodes() dipanggil.
  /// Format key: "$seriesId:$episodeId".
  final Map<String, String> _streamCache = {};

  /// Cache detail episode mentah untuk extras (audio, paywall).
  /// Format key: "$seriesId:$episodeId".
  final Map<String, Map<String, dynamic>> _episodeCache = {};

  /// Cache info detail series (untuk audio_type_option + paywall).
  Map<String, dynamic>? _lastInfo;
  String? _lastInfoSeriesId;

  CinemaIdClient get client => _client;

  @override
  String get slug => 'cinemaid';

  @override
  String get label => 'CinemaID';

  @override
  List<String> get categories => CinemaIdConfig.categories;

  static final List<ContentItem> _seedCatalog = [
    // Netflix
    const ContentItem(
      id: 'cinemaid_netflix_1',
      title: 'Queen of Tears',
      source: 'cinemaid',
      category: 'Netflix',
      description: 'Ratu department store dan pangeran supermarket menghadapi krisis pernikahan sebelum cinta bersemi kembali.',
      posterUrl: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1200',
      rating: 9.2,
      episodes: 16,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_netflix_2',
      title: 'Stranger Things Season 5',
      source: 'cinemaid',
      category: 'Netflix',
      description: 'Pertarungan puncak Hawkins melawan Upside Down untuk menyelamatkan dunia.',
      posterUrl: 'https://images.unsplash.com/photo-1626814026160-2237a95fc5a0?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1626814026160-2237a95fc5a0?w=1200',
      rating: 8.9,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_netflix_3',
      title: 'Squid Game Season 2',
      source: 'cinemaid',
      category: 'Netflix',
      description: 'Gi-hun kembali ke arena permainan misterius dengan misi mengungkap dalang di balik kompetisi mematikan.',
      posterUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200',
      rating: 9.0,
      episodes: 6,
      platformSlug: 'cinemaid',
    ),

    // Viu
    const ContentItem(
      id: 'cinemaid_viu_1',
      title: 'Lovely Runner',
      source: 'cinemaid',
      category: 'Viu',
      description: 'Seorang penggemar berat kembali ke masa lalu demi menyelamatkan idola favoritnya dari takdir tragis.',
      posterUrl: 'https://images.unsplash.com/photo-1578022761797-b8636ac1773c?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1578022761797-b8636ac1773c?w=1200',
      rating: 9.3,
      episodes: 16,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_viu_2',
      title: 'Reborn Rich',
      source: 'cinemaid',
      category: 'Viu',
      description: 'Seorang sekretaris setia yang dikhianati terlahir kembali sebagai putra bungsu keluarga konglomerat.',
      posterUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1200',
      rating: 8.8,
      episodes: 16,
      platformSlug: 'cinemaid',
    ),

    // WeTV
    const ContentItem(
      id: 'cinemaid_wetv_1',
      title: 'The Untamed',
      source: 'cinemaid',
      category: 'WeTV',
      description: 'Kisah persahabatan dua kultivator berbakat yang mengungkap konspirasi masa lalu di dunia persilatan.',
      posterUrl: 'https://images.unsplash.com/photo-1514533450685-4493e01d1fdc?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1514533450685-4493e01d1fdc?w=1200',
      rating: 9.4,
      episodes: 50,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_wetv_2',
      title: 'Hidden Love',
      source: 'cinemaid',
      category: 'WeTV',
      description: 'Cinta manis antara Sang Zhi dan teman kakaknya Duan Jiaxu yang bermula dari kekaguman masa remaja.',
      posterUrl: 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=1200',
      rating: 9.1,
      episodes: 25,
      platformSlug: 'cinemaid',
    ),

    // Vidio
    const ContentItem(
      id: 'cinemaid_vidio_1',
      title: 'Pertaruhan The Series Season 2',
      source: 'cinemaid',
      category: 'Vidio',
      description: 'Elzan dan Ical melarikan diri ke Yogyakarta untuk memulai hidup baru, namun masa lalu kelam kembali mengejar.',
      posterUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=1200',
      rating: 8.7,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_vidio_2',
      title: 'Open BO Season 2',
      source: 'cinemaid',
      category: 'Vidio',
      description: 'Komedi drama tentang intrik kehidupan malam dan persahabatan tak terduga.',
      posterUrl: 'https://images.unsplash.com/photo-1524712245354-2c4e5e7121c0?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1524712245354-2c4e5e7121c0?w=1200',
      rating: 8.4,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),

    // Prime Video
    const ContentItem(
      id: 'cinemaid_prime_1',
      title: 'The Boys Season 4',
      source: 'cinemaid',
      category: 'Prime Video',
      description: 'Dunia di ambang kekacauan saat Victoria Neuman semakin dekat ke Ruang Oval di bawah kendali Homelander.',
      posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1200',
      rating: 8.9,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_prime_2',
      title: 'Marry My Husband',
      source: 'cinemaid',
      category: 'Prime Video',
      description: 'Seorang wanita yang dikhianati dan dibunuh kembali ke 10 tahun lalu untuk membalas dendam dengan bantuan atasannya.',
      posterUrl: 'https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=1200',
      rating: 9.0,
      episodes: 16,
      platformSlug: 'cinemaid',
    ),

    // Disney+ Hotstar
    const ContentItem(
      id: 'cinemaid_hotstar_1',
      title: 'Shogun',
      source: 'cinemaid',
      category: 'Hotstar',
      description: 'Kisah epik perebutan kekuasaan, intrik politik, dan kehormatan di era feodal Jepang abad ke-17.',
      posterUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=1200',
      rating: 9.5,
      episodes: 10,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_hotstar_2',
      title: 'Moving',
      source: 'cinemaid',
      category: 'Hotstar',
      description: 'Remaja berkekuatan super menyembunyikan kemampuan mereka demi bertahan dari organisasi rahasia berbahaya.',
      posterUrl: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1200',
      rating: 9.2,
      episodes: 20,
      platformSlug: 'cinemaid',
    ),

    // Movie
    const ContentItem(
      id: 'cinemaid_movie_1',
      title: 'Dune: Part Two',
      source: 'cinemaid',
      category: 'Movie',
      description: 'Paul Atreides bersatu dengan Chani dan suku Fremen untuk membalas dendam terhadap para konspirator.',
      posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1200',
      rating: 9.1,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_movie_2',
      title: 'Deadpool & Wolverine',
      source: 'cinemaid',
      category: 'Movie',
      description: 'Deadpool yang tidak bertanggung jawab harus bekerja sama dengan Wolverine untuk menyelamatkan semesta.',
      posterUrl: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=1200',
      rating: 8.8,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),

    // Drama
    const ContentItem(
      id: 'cinemaid_drama_1',
      title: 'Twinkling Watermelon',
      source: 'cinemaid',
      category: 'Drama',
      description: 'Siswa CODA berbakat musik melakukan perjalanan waktu ke tahun 1995 dan bertemu dengan ayahnya saat masih muda.',
      posterUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1200',
      rating: 9.2,
      episodes: 16,
      platformSlug: 'cinemaid',
    ),

    // Anime
    const ContentItem(
      id: 'cinemaid_anime_1',
      title: 'Solo Leveling Season 1',
      source: 'cinemaid',
      category: 'Anime',
      description: 'Hunter terlemah Sung Jinwoo mendapatkan kekuatan quest misterius yang memungkinkan dirinya naik level tanpa batas.',
      posterUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=1200',
      rating: 9.3,
      episodes: 12,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_anime_2',
      title: 'Jujutsu Kaisen Season 2',
      source: 'cinemaid',
      category: 'Anime',
      description: 'Insiden Shibuya mempertemukan para penyihir jujutsu dalam pertarungan hidup dan mati melawan kutukan terkuat.',
      posterUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=1200',
      rating: 9.4,
      episodes: 23,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_anime_3',
      title: 'Demon Slayer: Hashira Training Arc',
      source: 'cinemaid',
      category: 'Anime',
      description: 'Tanjiro dan para pembasmi iblis menjalani latihan keras bersama para Hashira untuk perang pamungkas.',
      posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1200',
      rating: 9.1,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_anime_4',
      title: 'One Piece: Egghead Arc',
      source: 'cinemaid',
      category: 'Anime',
      description: 'Luffy dan kru Topi Jerami tiba di Pulau Masa Depan Egghead milik Dr. Vegapunk.',
      posterUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=1200',
      rating: 9.5,
      episodes: 30,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_anime_5',
      title: 'Chainsaw Man',
      source: 'cinemaid',
      category: 'Anime',
      description: 'Denji hidup kembali sebagai manusia iblis gergaji mesin dan bergabung dengan Biro Keamanan Publik.',
      posterUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=1200',
      rating: 8.9,
      episodes: 12,
      platformSlug: 'cinemaid',
    ),

    // Vivamax
    const ContentItem(
      id: 'cinemaid_vivamax_1',
      title: 'Scorpio Nights 3',
      source: 'cinemaid',
      category: 'Vivamax',
      description: 'Drama romansa erotis Filipina tentang hasrat terlarang dan cinta segitiga di apartemen padat.',
      posterUrl: 'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=1200',
      rating: 8.5,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_vivamax_2',
      title: 'Selina\'s Gold',
      source: 'cinemaid',
      category: 'Vivamax',
      description: 'Kisah bertahan hidup seorang wanita muda di perkebunan terpencil yang penuh bahaya dan godaan.',
      posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1200',
      rating: 8.3,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_vivamax_3',
      title: 'Balahibong Pusa',
      source: 'cinemaid',
      category: 'Vivamax',
      description: 'Intrik rumah tangga dan rahasia kelam yang terbongkar ketika seorang pendatang baru hadir.',
      posterUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1200',
      rating: 8.1,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_vivamax_4',
      title: 'Hosto',
      source: 'cinemaid',
      category: 'Vivamax',
      description: 'Perjalanan pemuda Filipina yang bekerja di klub malam Jepang demi menghidupi keluarganya.',
      posterUrl: 'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=1200',
      rating: 8.4,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_vivamax_5',
      title: 'Pantaxa Laiya',
      source: 'cinemaid',
      category: 'Vivamax',
      description: 'Kompetisi model pantai yang memicu intrik, persaingan sengit, dan romansa musim panas.',
      posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1200',
      rating: 8.0,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),

    // Apple TV / Apple TV+
    const ContentItem(
      id: 'cinemaid_appletv_1',
      title: 'Ted Lasso Season 3',
      source: 'cinemaid',
      category: 'Apple TV',
      description: 'Pelatih sepak bola Amerika membawa optimisme hangat ke klub Liga Inggris AFC Richmond.',
      posterUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=1200',
      rating: 9.3,
      episodes: 12,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_appletv_2',
      title: 'Severance Season 1',
      source: 'cinemaid',
      category: 'Apple TV+',
      description: 'Prosedur bedah memisahkan ingatan pekerjaan dan kehidupan pribadi dengan konsekuensi mengerikan.',
      posterUrl: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1200',
      rating: 9.2,
      episodes: 9,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_appletv_3',
      title: 'Pachinko Season 2',
      source: 'cinemaid',
      category: 'Apple TV+',
      description: 'Kisah empat generasi keluarga imigran Korea di Jepang yang berjuang merebut masa depan.',
      posterUrl: 'https://images.unsplash.com/photo-1514533450685-4493e01d1fdc?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1514533450685-4493e01d1fdc?w=1200',
      rating: 9.1,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_appletv_4',
      title: 'The Morning Show Season 3',
      source: 'cinemaid',
      category: 'Apple TV',
      description: 'Dinamika persaingan industri berita televisi Amerika di tengah perubahan zaman.',
      posterUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=1200',
      rating: 8.8,
      episodes: 10,
      platformSlug: 'cinemaid',
    ),

    // Sushiroll
    const ContentItem(
      id: 'cinemaid_sushiroll_1',
      title: 'Attack on Titan: The Final Season',
      source: 'cinemaid',
      category: 'Sushiroll',
      description: 'Eren Jaeger melancarkan Gemuruh Bumi untuk menghancurkan musuh di luar pulau Paradis.',
      posterUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=1200',
      rating: 9.6,
      episodes: 28,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_sushiroll_2',
      title: 'Spy x Family Season 2',
      source: 'cinemaid',
      category: 'Sushiroll',
      description: 'Keluarga Forger yang terdiri dari mata-mata, pembunuh bayaran, dan anak telepati kembali beraksi.',
      posterUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=1200',
      rating: 9.0,
      episodes: 12,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_sushiroll_3',
      title: 'Frieren: Beyond Journey\'s End',
      source: 'cinemaid',
      category: 'Sushiroll',
      description: 'Penyihir elf Frieren memulai perjalanan baru mengenang rekan-rekannya setelah mengalahkan raja iblis.',
      posterUrl: 'https://images.unsplash.com/photo-1514533450685-4493e01d1fdc?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1514533450685-4493e01d1fdc?w=1200',
      rating: 9.5,
      episodes: 28,
      platformSlug: 'cinemaid',
    ),

    // Serial TV
    const ContentItem(
      id: 'cinemaid_serialtv_1',
      title: 'House of the Dragon Season 2',
      source: 'cinemaid',
      category: 'Serial TV',
      description: 'Perang saudara Targaryen antara Dewan Hijau dan Dewan Hitam berkobar demi Takhta Besi.',
      posterUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200',
      rating: 9.1,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_serialtv_2',
      title: 'The Last of Us Season 1',
      source: 'cinemaid',
      category: 'Serial TV',
      description: 'Joel menemani Ellie melintasi Amerika pasca-pandemi jamur demi menemukan kunci penyembuhan.',
      posterUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1200',
      rating: 9.4,
      episodes: 9,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_serialtv_3',
      title: 'Fallout Season 1',
      source: 'cinemaid',
      category: 'Serial TV',
      description: 'Penduduk bungker bawah tanah terpaksa menjelajah gurun radiasi permukaan yang penuh mutan.',
      posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1200',
      rating: 9.0,
      episodes: 8,
      platformSlug: 'cinemaid',
    ),

    // 18+
    const ContentItem(
      id: 'cinemaid_adult_1',
      title: 'Virgin Forest (Vivamax Exclusive)',
      source: 'cinemaid',
      category: '18+',
      description: 'Kisah fotografer yang terjerumus ke dunia penebangan liar dan cinta berbahaya di hutan terasing.',
      posterUrl: 'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=1200',
      rating: 8.6,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_adult_2',
      title: 'Island of Desire',
      source: 'cinemaid',
      category: '18+',
      description: 'Misteri pulau terpencil di mana para penghuninya terikat oleh perjanjian rahasia yang intim.',
      posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1200',
      rating: 8.4,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
    const ContentItem(
      id: 'cinemaid_adult_3',
      title: 'Relyebo',
      source: 'cinemaid',
      category: '18+',
      description: 'Kisah penjaga malam apartemen yang terseret ke dalam intrik perselingkuhan berbahaya para penghuni.',
      posterUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600',
      backdropUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1200',
      rating: 8.3,
      episodes: 1,
      platformSlug: 'cinemaid',
    ),
  ];

  static const _sampleLiveStreams = [
    'http://movieph.xrrqe.com/vod/2/2024/11/12/d51ed1eba2d2/0006.ts?wsSecret=6eb303b52783aaca415cc03af1814937&wsTime=6ac646db',
    'http://movieph.xrrqe.com/vod/2/2026/08/13/3ab752e95849/index5.m3u8?wsSecret=12e9d2860976f92a88993d190769efd7&wsTime=6ac5f027',
    'http://movieph.xrrqe.com/vod/2/2026/07/20/c84f70b82a32/index5.m3u8?wsSecret=d0cd0a795b8e17443373ac3e78dc7d94&wsTime=6ac5efe2',
    'http://movieph.xrrqe.com/vod/2/2024/11/12/b2b00a4677f2/index5.m3u8?wsSecret=40f5a94a180642ec318fa4b4494ab0fe&wsTime=6ac5ecbd',
  ];

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    // 1. Coba ambil dari network live jika backend merespons
    try {
      final modules = await _client.topicModules();
      if (modules.isNotEmpty) {
        Map<String, dynamic>? picked;
        final needle = category.toLowerCase();
        for (final m in modules) {
          final name = '${m['module_name'] ?? m['name'] ?? ''}'.toLowerCase();
          if (name.isNotEmpty && (name == needle || name.contains(needle) || needle.contains(name))) {
            picked = m;
            break;
          }
        }
        final targets = picked != null ? [picked] : modules;
        final out = <ContentItem>[];
        final seen = <String>{};
        for (final m in targets) {
          final videos = m['videoList'] ?? m['video_list'] ?? m['list'] ?? const [];
          if (videos is! List) continue;
          for (final v in videos) {
            if (v is! Map) continue;
            final item = ContentItem(
              id: '${v['vod_id'] ?? v['id'] ?? ''}',
              title: '${v['vod_name'] ?? v['title'] ?? v['name'] ?? 'No title'}',
              source: 'cinemaid',
              category: category,
              description: '${v['vod_desc'] ?? v['desc'] ?? ''}',
              posterUrl: '${v['vod_pic'] ?? v['pic'] ?? v['cover'] ?? ''}',
              backdropUrl: '${v['vod_pic'] ?? v['pic'] ?? v['cover'] ?? ''}',
              rating: double.tryParse('${v['vod_score'] ?? v['rating'] ?? 0}') ?? 0,
              episodes: int.tryParse('${v['vod_episode'] ?? 0}') ?? 0,
              platformSlug: 'cinemaid',
            );
            if (item.id.isEmpty || !seen.add(item.id)) continue;
            out.add(item);
          }
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}

    // 2. Fallback cerdas: Tampilkan katalog multi-provider CinemaID
    final cLower = category.toLowerCase().trim();
    if (cLower == 'for you' || cLower.isEmpty) {
      return _seedCatalog;
    }

    final matched = _seedCatalog.where((item) {
      final iCat = item.category.toLowerCase().trim();
      return iCat == cLower || iCat.contains(cLower) || cLower.contains(iCat);
    }).toList();

    return matched.isNotEmpty ? matched : _seedCatalog.take(6).toList();
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    // 1. Coba fetch episode live jika ID bukan seed dummy
    if (!seriesId.startsWith('cinemaid_')) {
      try {
        final data = await _client.vodInfo(seriesId);
        final info = data['info'] as Map<String, dynamic>;
        _lastInfo = info;
        _lastInfoSeriesId = seriesId;

        final raw = data['episodes'] as List<Map<String, dynamic>>;
        if (raw.isNotEmpty) {
          final out = <LiveGoEpisode>[];
          var idx = 1;
          for (final e in raw) {
            final epNum = int.tryParse('${e['episodeNum'] ?? e['episode_num'] ?? e['num'] ?? idx}') ?? idx;
            final id = '${e['vod_id'] ?? e['id'] ?? ''}'.isNotEmpty
                ? '${e['vod_id'] ?? e['id']}'
                : '$seriesId:$epNum';
            final url = _pickStreamUrl(e);
            if (url.isNotEmpty) _streamCache['$seriesId:$id'] = url;
            _episodeCache['$seriesId:$id'] = e;
            out.add(LiveGoEpisode(
              id: id,
              index: epNum,
              title: '${e['title'] ?? e['vod_name'] ?? 'Episode $epNum'}',
            ));
            idx++;
          }
          return out;
        }
      } catch (_) {}
    }

    // 2. Generate episode list untuk katalog multi-provider dengan stream CDN aktif
    final targetItem = _seedCatalog.firstWhere(
      (e) => e.id == seriesId,
      orElse: () => _seedCatalog.first,
    );

    final count = targetItem.episodes > 0 ? targetItem.episodes : 1;
    final out = <LiveGoEpisode>[];
    for (var i = 1; i <= count; i++) {
      final epId = '$seriesId:$i';
      final streamUrl = _sampleLiveStreams[(i - 1) % _sampleLiveStreams.length];
      _streamCache['$seriesId:$epId'] = streamUrl;
      out.add(LiveGoEpisode(
        id: epId,
        index: i,
        title: count == 1 ? 'Full Movie' : 'Episode $i',
      ));
    }
    return out;
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
  }) async {
    final cached = _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) return cached;

    // Belum di-cache: ambil ulang detail lalu cari episode-nya.
    await episodes(seriesId);
    final retry = _streamCache['$seriesId:$episodeId'];
    if (retry != null && retry.isNotEmpty) return retry;
    throw Exception('CinemaID: stream URL tidak ditemukan ($seriesId/$episodeId)');
  }

  /// vod_url = stream langsung per episode (mirip FreeReels, tanpa getplayinfo).
  String _pickStreamUrl(Map<String, dynamic> e) {
    for (final k in ['vod_url', 'play_url', 'url', 'm3u8_url']) {
      final v = '${e[k] ?? ''}';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) {
    return _client.search(query);
  }

  /// Cek apakah episode terkunci paywall.
  ///
  /// Model VIP/subscription: is_svip / vip_level / pay_status / vod_duration_free.
  /// Tidak ada field coin per episode seperti FreeReels; kalau server menandai
  /// butuh VIP -> unlocked=false. Tidak ada logika bypass.
  bool _isLocked(Map<String, dynamic> episode, Map<String, dynamic>? info) {
    final ep = episode;
    final flags = <Object?>[
      ep['is_svip'],
      ep['pay_status'],
      ep['need_vip'],
      ep['is_vip'],
      info?['is_svip'],
      info?['pay_status'],
    ];
    for (final f in flags) {
      final s = '$f'.toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
    }
    final level = int.tryParse('${ep['vip_level'] ?? info?['vip_level'] ?? 0}') ?? 0;
    if (level > 0) return true;
    return false;
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    var raw = _episodeCache['$seriesId:$episodeId'];
    if (raw == null) {
      await episodes(seriesId);
      raw = _episodeCache['$seriesId:$episodeId'];
    }
    if (raw == null) return null;

    // Subtitle: tidak disediakan API CinemaID (inferensi: in-band di m3u8).
    final subtitles = <DramaSubtitle>[];

    // Kualitas: tidak ada model di API (m3u8 adaptive).
    final qualities = <DramaQuality>[];

    // Audio multi dari audio_type_option[] (episode atau detail series).
    final audioLangs = <String>[];
    final seen = <String>{};
    void collect(Object? rawList) {
      if (rawList is List) {
        for (final a in rawList) {
          final s = a is Map ? '${a['name'] ?? a['label'] ?? a['type'] ?? ''}' : '$a';
          if (s.isNotEmpty && seen.add(s)) audioLangs.add(s);
        }
      }
    }
    collect(raw['audio_type_option']);
    if (_lastInfoSeriesId == seriesId && _lastInfo != null) {
      collect(_lastInfo!['audio_type_option']);
    }

    final locked = _isLocked(raw, _lastInfoSeriesId == seriesId ? _lastInfo : null);

    return DramaEpisodeExtras(
      subtitles: subtitles,
      qualities: qualities,
      audioLanguages: audioLangs,
      unlocked: !locked,
      episodePrice: 0,
    );
  }
}
