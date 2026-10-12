/// Konfigurasi resmi dan fallback ShortTV API untuk LiveGo Mandiri.
class ShortTvConfig {
  /// Base host API ShortTV
  static const String baseUrl = 'https://api.shorttv.live';

  /// Fallback host jika domain utama lambat atau terblokir
  static const List<String> fallbackHosts = [
    'https://api.shorttv.live',
    'https://api.shorttv.app',
  ];

  /// Host CDN gambar dan poster drama
  static const String cdnHost = 'https://akamai-static.shorttv.live';

  /// Default Client Credentials
  static const String defaultDeviceId = 'c73b5f8fa01cb4794a9f031ae8d23bd3';
  static const String defaultRc4Key = 'wEG31caHzIq6lPs7uXg2xnsBoW384ECT';
  static const String defaultRc4RsaKey =
      'FKT0pHYnFJQs5X3uaTU4xhT4cbf36vCpFnud17/C2klbZ6eZz7RjXMXXZgZ+76tDu8KW7teA1odu/qA/lVoxKWxnKWuGMw3WiRVGiTK1pFcLDH7A+8FoGRww2BrVy8d3wNPdlUX2aw5dUYA3XhVuHJwl0LK3rt6h5D9Ef2fp1bs=';

  /// Initial / fallback token (akan diperbarui otomatis via initLogin)
  static const String defaultToken =
      '1pkeeporqzC4ou7Jk1fWnuZOfTmmPzFXbRKqbYUFKCbaHJFVMkjd0nlWvoPxQjUXOP3tkiCXSNnXb6JYwd05IX3woU+Nz+Q8PAYMA8YSwEqxaeKlXfbeWvv2l+YbPtsfZSWtr8a+8WpI69517CfEjEweP/wevRQkRzNjrnkZ+ymRyalZ4K5tq/ODBN0L2zE8G3yLyhosgQBGJmhwWJRL9fB6mncMxjh5MzZNArqIxJslfOt0rv3O2d0oVi0PVX6olw5Jx8vY/E9v2zDco7Bjge8kYeOxj5G4a+MQa9hEUjv/ArviO+UKHYXhCqsyyfX6BeTexZiM3x6ido17D5RDYzz+8pAf2qP4BZgLwWVbbqUsA9CaFRTk76+OESyvqQkMheWPZCmXPgo81E29V2VO1JD8vmc3scu1ebFFsSj+ENZnB1C5mmf7CAAGNBjg3D2os+m8in4amWWy4BwDipbsV4r/FwUMeJDkEYgv41s94ppNsN8PiN1ryo+I3L0RwJaOnPY3n7zyg8XwLpZyEuzkqzi7MW+BDBYPq/7DkiW5T40OFq0H3yv8OG1Xuw/qQicwYOUdmlmoMVZeUa3yUwdugIg5nLHTjso2aCOUOTN7UhMlcedEKSnuNr3y8aYh7hqM40rCiXMkGMm8m9NTrDrj57OaKAncjIkuSHRwvFvnoEnS+QXTB9kGeB0WbE2rK1goDOFUua2mRsqg8oosu3hLl2FMWAJ8w5cp0Cmc9mFGcvEgFcx+xzk2QvuKbKuejhc/tQ6OUS1SZjf1rNiZG5s3ZHPTaeMO0V2tR7iAWyFJH1vXqL7uok29yeRGWBNQ8UlSaI/+aWEP6SU61uTSXeQMw3v1GCG5b1zLDl09glQ7YmNqhJmjj+ONOuIBm2G10wqZbmsxuRyTLtwTpjRyKYaWtLFflC2dJs8LRfD16NRsKyLHYDJdgq887lDtrkO709AmB6hsuFgEJZ87kG0RHB7I6chJIl2RL29yOmjHkM97KBcQV9WkXBXpZnAbmg0TZkyCA/itqsvO/VVJZoCrZGEMjj0438tB+VcguYxvfefsM4+QS2F9XMnTnWlV+VMvhoCf7G0KPsaymI/F8ZMrWJs4mj5UXlKk3m24N1qBaRiRbDVZRNWr7wvc8rK1hADvlhwtrCFkTM2nynGtc0Vb7macfw==';

  /// Timeout jaringan
  static const Duration timeout = Duration(seconds: 15);

  /// Kategori bawaan ShortTV
  static const List<String> categories = [
    'Semua',
    'Trending Indonesia',
    'Global / English',
    'Jepang',
    'Spanyol',
    'Thailand',
    'Vietnam',
    'Portugis',
  ];

  /// Pemetaan kategori ke kode bahasa dan negara ShortTV
  static const Map<String, ({String lang, String locale, String country})> categoryMapping = {
    'Semua': (lang: 'id', locale: 'id_ID', country: 'ID'),
    'Trending Indonesia': (lang: 'id', locale: 'id_ID', country: 'ID'),
    'Global / English': (lang: 'en', locale: 'en_US', country: 'US'),
    'Jepang': (lang: 'ja', locale: 'ja_JP', country: 'JP'),
    'Spanyol': (lang: 'es', locale: 'es_ES', country: 'ES'),
    'Thailand': (lang: 'th', locale: 'th_TH', country: 'TH'),
    'Vietnam': (lang: 'vi', locale: 'vi_VN', country: 'VN'),
    'Portugis': (lang: 'pt', locale: 'pt_BR', country: 'BR'),
  };
}
