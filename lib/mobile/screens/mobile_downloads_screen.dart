import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../services/download/download_service.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../../services/image/image_quality_config.dart';

class MobileDownloadsScreen extends StatelessWidget {
  const MobileDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final rows = DownloadService.items;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          children: [
            _Header(count: rows.length),
            const SizedBox(height: 18),
            if (rows.isEmpty)
              const _EmptyDownloads()
            else ...[
              Row(
                children: [
                  const Text('Daftar Unduhan', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: DownloadService.clear,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Bersihkan'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final row in rows) _DownloadTile(record: row),
            ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.download_done_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Download', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('$count episode tersimpan / antre di perangkat ini', style: const TextStyle(color: AppTheme.textSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadRecord record;
  const _DownloadTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final status = _statusText(record.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 62,
              height: 86,
              child: LiveGoCachedImage(url: record.item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${record.item.platformSlug} • Eps ${record.episode} • ${record.quality}', style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: record.progress <= 0 ? null : record.progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  color: AppTheme.cyan,
                ),
                const SizedBox(height: 6),
                Text(record.error.isNotEmpty ? '$status • ${record.error}' : status, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => DownloadService.remove(record),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  static String _statusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return 'Menunggu';
      case DownloadStatus.downloading:
        return 'Mengunduh';
      case DownloadStatus.completed:
        return 'Selesai';
      case DownloadStatus.failed:
        return 'Gagal';
      case DownloadStatus.canceled:
        return 'Dibatalkan';
    }
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_for_offline_rounded, color: AppTheme.cyan, size: 56),
          SizedBox(height: 16),
          Text('Download masih kosong', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('Tekan tombol Unduh di player untuk menyimpan episode ke perangkat.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSoft, height: 1.45)),
        ],
      ),
    );
  }
}
