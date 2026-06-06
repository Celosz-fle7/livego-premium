import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/poster_card.dart';
import '../../tv/player/tv_player_entry.dart';

class MobileLibraryScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool favorites;

  const MobileLibraryScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.favorites,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final items = favorites ? LiveGoLocalStore.favorites : LiveGoLocalStore.history;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          children: [
            _Header(title: title, icon: icon, count: items.length),
            const SizedBox(height: 20),
            if (items.isEmpty)
              _Empty(title: title, favorites: favorites)
            else ...[
              Row(
                children: [
                  Text(
                    favorites ? 'Judul tersimpan' : 'Terakhir diputar',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: favorites ? LiveGoLocalStore.clearFavorites : LiveGoLocalStore.clearHistory,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Bersihkan'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 265,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return PosterCard(
                    item: item,
                    onTap: () => TvPlayerEntry.open(context, item: item),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  const _Header({required this.title, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF24344A)),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.06), blurRadius: 28)],
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
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('$count judul tersimpan di perangkat ini', style: const TextStyle(color: AppTheme.textSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final bool favorites;
  const _Empty({required this.title, required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(favorites ? Icons.favorite_rounded : Icons.history_rounded, color: AppTheme.cyan, size: 56),
          const SizedBox(height: 16),
          Text('$title masih kosong', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            favorites ? 'Tekan tombol favorit di detail/player untuk menyimpan judul.' : 'Judul yang kamu buka akan muncul otomatis di sini.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSoft, height: 1.45),
          ),
        ],
      ),
    );
  }
}
