import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';
import '../../models/stream_info.dart';

class DownloadService {
  static List<DownloadRecord> get items => LiveGoLocalStore.downloads;

  static Future<DownloadRecord> enqueue({
    required ContentItem item,
    required int episode,
    required StreamInfo stream,
    String quality = 'Auto',
  }) async {
    final now = DateTime.now();
    final record = DownloadRecord(
      item: item,
      episode: episode,
      quality: quality,
      url: stream.url,
      localPath: '',
      progress: 0,
      status: stream.url.isEmpty ? DownloadStatus.failed : DownloadStatus.queued,
      updatedAt: now,
      error: stream.url.isEmpty ? 'Stream belum tersedia dari API.' : '',
    );
    await LiveGoLocalStore.addOrUpdateDownload(record);
    if (stream.url.isEmpty) return record;
    return _download(record, stream.headers);
  }

  static Future<DownloadRecord> _download(DownloadRecord record, Map<String, String> headers) async {
    await LiveGoLocalStore.addOrUpdateDownload(record.copyWith(status: DownloadStatus.downloading, updatedAt: DateTime.now()));
    try {
      final dir = await getApplicationDocumentsDirectory();
      final root = Directory('${dir.path}/livego_downloads/${record.item.platformSlug}/${record.item.id}');
      if (!await root.exists()) await root.create(recursive: true);
      final ext = _ext(record.url);
      final file = File('${root.path}/episode_${record.episode}_${record.quality.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.$ext');

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(record.url));
      headers.forEach(req.headers.set);
      req.headers.set('User-Agent', headers['User-Agent'] ?? 'okhttp/4.12.0');
      req.headers.set('Accept', headers['Accept'] ?? '*/*');
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('HTTP ${res.statusCode}');

      final total = res.contentLength;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          await LiveGoLocalStore.addOrUpdateDownload(record.copyWith(
            localPath: file.path,
            progress: (received / total).clamp(0.0, 1.0),
            status: DownloadStatus.downloading,
            updatedAt: DateTime.now(),
          ));
        }
      }
      await sink.flush();
      await sink.close();
      client.close(force: true);

      final done = record.copyWith(localPath: file.path, progress: 1, status: DownloadStatus.completed, updatedAt: DateTime.now(), error: '');
      await LiveGoLocalStore.addOrUpdateDownload(done);
      return done;
    } catch (e) {
      final failed = record.copyWith(status: DownloadStatus.failed, updatedAt: DateTime.now(), error: '$e');
      await LiveGoLocalStore.addOrUpdateDownload(failed);
      return failed;
    }
  }

  static Future<void> remove(DownloadRecord record) async {
    if (record.localPath.isNotEmpty) {
      final file = File(record.localPath);
      if (await file.exists()) await file.delete();
    }
    await LiveGoLocalStore.removeDownload(record);
  }

  static Future<void> clear() => LiveGoLocalStore.clearDownloads();

  static String _ext(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m3u8')) return 'm3u8';
    if (path.endsWith('.mp4')) return 'mp4';
    return 'video';
  }
}
