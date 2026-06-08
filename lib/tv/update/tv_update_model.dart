class TvUpdateAppInfo {
  final String versionName;
  final int versionCode;

  const TvUpdateAppInfo({
    required this.versionName,
    required this.versionCode,
  });

  factory TvUpdateAppInfo.fromMap(Map<dynamic, dynamic> map) {
    return TvUpdateAppInfo(
      versionName: '${map['versionName'] ?? '0.0.0'}',
      versionCode: int.tryParse('${map['versionCode'] ?? 0}') ?? 0,
    );
  }
}

class TvUpdateInfo {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String sha256;
  final List<String> changelog;
  final bool requiredUpdate;

  const TvUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.sha256,
    required this.changelog,
    required this.requiredUpdate,
  });

  factory TvUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawChangelog = json['changelog'];
    final rows = rawChangelog is List
        ? rawChangelog.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList(growable: false)
        : <String>[];

    return TvUpdateInfo(
      versionName: '${json['versionName'] ?? ''}'.trim(),
      versionCode: int.tryParse('${json['versionCode'] ?? 0}') ?? 0,
      apkUrl: '${json['apkUrl'] ?? ''}'.trim(),
      sha256: '${json['sha256'] ?? ''}'.trim().toLowerCase(),
      changelog: rows,
      requiredUpdate: json['required'] == true || '${json['required']}'.toLowerCase() == 'true',
    );
  }

  bool isNewerThan(TvUpdateAppInfo current) => versionCode > current.versionCode;

  bool get hasApk => apkUrl.startsWith('http://') || apkUrl.startsWith('https://');
}
