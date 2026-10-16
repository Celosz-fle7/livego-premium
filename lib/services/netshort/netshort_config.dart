/// Konfigurasi API NetShort (com.netshort.abroad)
class NetShortConfig {
  static const String baseUrl = 'https://appsecapi.netshort.com/prod-app-api';
  static const String packageName = 'com.netshort.abroad';
  static const String appVersion = '2.3.3';
  static const String versionCode = '245';
  static const String os = '1';
  static const String canary = 'v2';
  static const String defaultLanguage = 'id_ID';
  static const String defaultModel = 'CPH2343';
  static const String defaultOsVer = '12';

  // Endpoint paths
  static const String authLogin = '/auth/login';
  static const String theaterHomeInfo = '/video/shortPlay/theater/home/info';
  static const String theaterChannelVideo = '/video/shortPlay/theater/home/channel-video';
  static const String tabLoadAllChart = '/video/shortPlay/tab/load_all_chart';
  static const String detailInfoV2 = '/video/shortPlay/base/detail_info/V2';
  static const String episodeDetailInfo = '/video/shortPlay/base/episode/detail_info';
  static const String searchRealtime = '/video/shortPlay/search/realtime';
}
