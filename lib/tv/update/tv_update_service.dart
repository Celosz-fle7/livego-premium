import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'tv_update_model.dart';

class TvUpdateCheckResult {
  final TvUpdateAppInfo current;
  final TvUpdateInfo? latest;
  final bool updateAvailable;
  final String message;

  const TvUpdateCheckResult({
    required this.current,
    required this.latest,
    required this.updateAvailable,
    required this.message,
  });
}

class TvUpdateDownloadResult {
  final String path;
  final int bytes;

  const TvUpdateDownloadResult({
    required this.path,
    required this.bytes,
  });
}

class TvUpdateService {
  const TvUpdateService();

  static const MethodChannel _channel = MethodChannel('livego/app_updater');

  static const String manifestUrl =
      'https://github.com/Celosz-fle7/livego-premium/releases/latest/download/livego-version.json';

  Future<TvUpdateAppInfo> currentAppInfo() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppInfo');
    if (raw == null) {
      return const TvUpdateAppInfo(versionName: '0.0.0', versionCode: 0);
    }
    return TvUpdateAppInfo.fromMap(raw);
  }

  Future<TvUpdateCheckResult> check() async {
    final current = await currentAppInfo();
    final latest = await _fetchManifest();

    if (latest.versionCode <= 0 || !latest.hasApk) {
      return TvUpdateCheckResult(
        current: current,
        latest: latest,
        updateAvailable: false,
        message: 'Manifest update belum valid.',
      );
    }

    if (!latest.isNewerThan(current)) {
      return TvUpdateCheckResult(
        current: current,
        latest: latest,
        updateAvailable: false,
        message: 'Aplikasi sudah versi terbaru.',
      );
    }

    return TvUpdateCheckResult(
      current: current,
      latest: latest,
      updateAvailable: true,
      message: 'Update tersedia: ${latest.versionName} (${latest.versionCode}).',
    );
  }

  Future<TvUpdateDownloadResult> downloadApk(
    TvUpdateInfo update, {
    required void Function(double progress) onProgress,
  }) async {
    if (!update.hasApk) {
      throw StateError('URL APK update belum valid.');
    }

    final dir = await getTemporaryDirectory();
    final updateDir = Directory('${dir.path}/livego_update');
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }

    final outFile = File('${updateDir.path}/livego-tv-update-${update.versionCode}.apk');
    final tempFile = File('${outFile.path}.part');
    if (await tempFile.exists()) await tempFile.delete();
    if (await outFile.exists()) await outFile.delete();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(Uri.parse(update.apkUrl));
      request.followRedirects = true;
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final total = response.contentLength;
      var received = 0;
      final sink = tempFile.openWrite();

      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress((received / total).clamp(0.0, 1.0).toDouble());
        }
      }

      await sink.flush();
      await sink.close();

      if (update.sha256.isNotEmpty) {
        final actual = await _sha256Of(tempFile);
        if (actual.toLowerCase() != update.sha256.toLowerCase()) {
          await tempFile.delete();
          throw StateError('Checksum APK tidak cocok.');
        }
      }

      await tempFile.rename(outFile.path);
      onProgress(1.0);
      return TvUpdateDownloadResult(path: outFile.path, bytes: received);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> openInstaller(String apkPath) async {
    await _channel.invokeMethod<bool>('installApk', <String, Object?>{
      'path': apkPath,
    });
  }

  Future<TvUpdateInfo> _fetchManifest() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);

    try {
      final request = await client.getUrl(Uri.parse(manifestUrl));
      request.followRedirects = true;
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final text = await response.transform(utf8.decoder).join();
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Manifest bukan JSON object.');
      }
      return TvUpdateInfo.fromJson(json);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
