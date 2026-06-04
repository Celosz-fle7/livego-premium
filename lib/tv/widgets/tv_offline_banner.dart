import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class TvOfflineBanner extends StatelessWidget {
  final bool visible;
  final bool fromCache;
  final bool refreshing;

  const TvOfflineBanner({
    super.key,
    required this.visible,
    this.fromCache = false,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final title = fromCache
        ? 'Mode cache aktif'
        : 'Jaringan atau source sedang bermasalah';
    final message = refreshing
        ? 'Konten tetap bisa dipakai. Pembaruan berjalan pelan di belakang.'
        : (fromCache
            ? 'Konten lama ditampilkan supaya remote tidak stuck di loading.'
            : 'Tekan OK di area kosong untuk coba lagi, atau ganti source.');

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title • $message',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
