import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/poster_card.dart';
import '../mobile_player_entry.dart';

class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({super.key});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final _controller = TextEditingController();
  String query = '';
  int platform = -1;
  bool loading = false;
  List<ContentItem> results = [];

  Future<void> _search(String value) async {
    query = value.trim();
    if (query.isEmpty) {
      setState(() => results = []);
      return;
    }
    setState(() => loading = true);
    final items = platform < 0
        ? await LiveGoCatalog.searchAll(query)
        : await LiveGoCatalog.search(query, platform: LiveGoCatalog.platforms[platform]);
    if (!mounted) return;
    setState(() {
      results = items;
      loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const Text('Pencarian', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Cari semua sumber aktif atau pilih platform tertentu.', style: TextStyle(color: AppTheme.textSoft)),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Cari drama, CEO, cinta, balas dendam...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          ),
          onSubmitted: _search,
          onChanged: (v) {
            query = v;
            if (v.trim().isEmpty) _search(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: platform < 0,
                  label: const Text('Semua Source'),
                  onSelected: (_) {
                    setState(() => platform = -1);
                    if (query.isNotEmpty) _search(query);
                  },
                ),
              ),
              ...List.generate(LiveGoCatalog.platformLabels.length, (i) {
                final selected = platform == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(LiveGoCatalog.platformLabels[i]),
                    onSelected: (_) {
                      setState(() => platform = i);
                      if (query.isNotEmpty) _search(query);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 70),
            child: Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
          )
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 70),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.travel_explore_rounded, color: Colors.white.withOpacity(0.25), size: 70),
                  const SizedBox(height: 14),
                  const Text('Cari dari source aktif LiveGo', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 265,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            itemBuilder: (_, i) {
              final item = results[i];
              return PosterCard(
                item: item,
                onTap: () => MobilePlayerEntry.open(context, item: item),
              );
            },
          ),
      ],
    );
  }
}
